require 'http'
require 'json'
require 'faye/websocket'
require 'eventmachine'

# response = HTTP.post('https://slack.com/api/chat.postMessage', params: {
#   token: ENV['SLACK_API_TOKEN'],
#   channel: "D5T0RN8UR",
#   text: 'テスト',
#   as_user: true,
# })
# puts JSON.pretty_generate(JSON.parse(response.body))

class Bot
  def initialize(client)
    @client = client
  end

  def speak(text: nil, channel: nil) # この処理が頻繁に出るのでクラスにまとめてみた
    return if channel.nil? || text.nil?
    @client.send({
      type: 'message',
      text: text,
      channel: channel,
    }.to_json)
  end

  def archive(text: nil)              # hall_of_kazmax投稿用
    speak(text: text, channel: 'C5V0WKG90')
  end
end

response = HTTP.post('https://slack.com/api/rtm.start', params: {
  token: ENV['SLACK_API_TOKEN'],
})
rc = JSON.parse(response.body)
url = rc['url']
p url

response = HTTP.post('https://slack.com/api/emoji.list', params: {
  token: ENV['SLACK_API_TOKEN'],
})
rc = JSON.parse(response.body)
emoji = rc['emoji'] # 絵文字の一覧取っておく

EM.run do
  ws = Faye::WebSocket::Client.new(url)
  kazmax = Bot.new(ws)

  ws.on :open do
    p [:open]
  end

  ws.on :message do |event|
    data = JSON.parse(event.data)
    # p [:message, data] # デバッグ時､JSONを吐き出させる用

    if !data.has_key?('reply_to') && data['subtype'] != "bot_message" && data['channel']!='C5V0WKG90' # 他のchatbotならスルー（無限ループ回避）､hall_of_kazmaxチャネルはスルー
      if data['text'] =~ /(<@U5THEG8UA>)/ # 自分宛てのメンションのみ
        if data['text'] =~ /<(https:\/\/kaz-max.slack.com\/archives\/.+)>/ # Slack内のコメントリンク
          ws.send({
            type: 'message',
            text: "エエ話や〜",
            channel: data['channel'],
          }.to_json)
          ws.send({
            type: 'message',
            text: "#{$1}", # ポスト､本当は中身を読み出して前後のブロックごと貼りたい･･
            channel: "C5V0WKG90",
          }.to_json)
        elsif data['text'] =~ /<(https?:\/\/.+)>/ # slack内ではない記事
          ws.send({
            type: 'message',
            text: "ふむふむ良記事",
            channel: data['channel'],
          }.to_json)
          ws.send({
            type: 'message',
            text: "#{$1}",
            channel: "C5V0WKG90",
          }.to_json)
        else                      # リンクがなければ何もしないよ
          ws.send({
            type: 'message',
            text: "(ニヤニヤ)",
            channel: data['channel'],
          }.to_json)
        end
      end
    end

    if data['text'] =~ /kazmax/i || data['text'] =~ /カズマさん/ || data['text'] =~ /一真さん/ # 呼びかけに反応
      random_emoji = emoji.keys[rand(0..emoji.size-1)] # 絵文字をランダムに選ぶ
      # ws.send({
      #   type: 'message',
      #   text: ":#{random_emoji}:",
      #   channel: data['channel'],
      #   timestamp: data['ts'],
      # }.to_json)
    end

    if data['text'] =~ /こんにちは/
      ws.send({
        type: 'message',
        text: "ご機嫌はいかがかな？<@#{data['user']}>さん",
        channel: data['channel'],
      }.to_json)
    end

    if data['text'] =~ /お名前は/
      r = rand(0..9)
      if (r < 3)
        ws.send({
          type: 'message',
          text: "Kaz-max",
          channel: data['channel'],
        }.to_json)
      elsif (r < 5)
        ws.send({
          type: 'message',
          text: "エリーツ最高",
          channel: data['channel'],
        }.to_json)
      else
        random_emoji = emoji.keys[rand(0..emoji.size-1)]
        ws.send({
          type: 'message',
          text: ":#{random_emoji}:",
          channel: data['channel'],
          timestamp: data['ts'],
        }.to_json)
      end
    end

    if data['text'] =~ /おはよう/
      ws.send({
        type: 'message',
        text: "<@#{data['user']}>たんおっはよ〜♪",
        channel: data['channel'],
      }.to_json)
    end

    if data['text'] =~ /ご招待/
      ws.send({
        type: 'message',
        text: "チャネル登録はこちら\n https://kaz-max.herokuapp.com/",
        channel: data['channel'],
      }.to_json)
    end

  end

  ws.on :close do |event|
    p [:close, event.code]
    ws = nil
    EM.stop
  end

end
