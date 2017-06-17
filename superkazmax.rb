require 'http'
require 'json'
require 'faye/websocket'
require 'eventmachine'

KAZMAX = '<@U579AK65C>'.freeze
SUPERKAZMAX = '<@U5THEG8UA>'.freeze
HALL_OF_KAZMAX = 'C5V0WKG90'.freeze

# response = HTTP.post('https://slack.com/api/chat.postMessage', params: {
#   token: ENV['SLACK_API_TOKEN'],
#   channel: "D5T0RN8UR",
#   text: 'テスト',
#   as_user: true,
# })
# puts JSON.pretty_generate(JSON.parse(response.body))

class Bot                 # 毎回おなじような処理を書くのはツライのでクラス化する
  def initialize(client)
    @client = client
  end

  def speak(data=nil, text: nil)
    return if data.nil?
    post(text: text, channel: data['channel'])
  end

  def archive(text: nil)              # hall_of_kazmax投稿用
    post(text: text, channel: HALL_OF_KAZMAX)
  end

  private

  def post(text: nil, channel: nil)   # この処理が頻繁に出る
    return if channel.nil? || text.nil?
    @client.send({
      type: 'message',
      text: text,
      channel: channel,
    }.to_json)
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
    p [:message, data] # デバッグ時､JSONを吐き出させる用

    if !data.has_key?('reply_to') && data['subtype'] != "bot_message" && data['channel']!='C5V0WKG90' # 他のchatbotならスルー（無限ループ回避）､hall_of_kazmaxチャネルはスルー
      if data['text'] =~ /#{SUPERKAZMAX}/ # 自分宛てのメンションのみ
        if data['text'] =~ /<(https:\/\/kaz-max.slack.com\/archives\/.+)>/ # Slack内のコメントリンク
          text = ['エエ話や〜', 'これはいいこと言っている', '微妙な発言ですがいいでしょう･･', '承知いたしました' ].sample
          kazmax.speak(data, text: text)
          kazmax.archive("#{$1}")
        elsif data['text'] =~ /<(https?:\/\/.+)>/ # slack内ではない記事
          text = ['ふむふむ良記事', 'おっこれは', 'りょ', 'すぽぽぽぽぽぽぽーん❗' , '保管します'].sample
          kazmax.speak(data, text: text)
          kazmax.archive("#{$1}")
        else                      # リンクがなければ何もしないよ
          text = ['何を保存しますか？', '(ニヤニヤ)', 'リンクが見えないのは私だけでしょうか･･' ].sample
          kazmax.speak(data, text: text)
        end
      end
    end

    if data['text'] =~ /kazmax/i || data['text'] =~ /カズマックス/ || data['text'] =~ /カズマさん/ || data['text'] =~ /一真さん/ # 呼びかけに反応
      random_emoji = emoji.keys[rand(0..emoji.size-1)] # 絵文字をランダムに選ぶ
      kazmax.speak(text: ":#{random_emoji}:", channel: data['channel'])
    end

    if data['text'] =~ /#{SUPERKAZMAX}/ # 自分宛てのメンションのみ
      kazmax.speak(data, text: "新宿の天気: #{weather_shinjuku}")

      if data['text'] =~ /お名前は/
        text = ['kazmax','スーパーkazmax',"#{KAZMAX}に聞いてください",'エリーツ最高','名乗るほどのものではありません'].sample
        kazmax.speak(data, text: text)
      end

      if data['text'] =~ /天気/
        weather_iwate = "http://www.tenki.jp/forecast/2/6/3310/3214-1hour.html"
        weather_shinjuku = "http://www.tenki.jp/forecast/3/16/4410/13104-1hour.html"
        weather_kamakura = "http://www.tenki.jp/forecast/3/17/4610/14204-1hour.html"

        if data['text'] =~ /(.+)の天気/
          if $1 =~ /新宿/
            kazmax.speak(data, text: "新宿の天気: #{weather_shinjuku}")
          end
          if $1 =~ /八幡平/
            kazmax.speak(data, text: "八幡平の天気: #{weather_iwate}")
          end
          if $1 =~ /八幡平/
            kazmax.speak(data, text: "鎌倉の天気: #{weather_kamakura}")
          end
        else
          kazmax.speak(data, text: "八幡平の天気: #{weather_iwate}")
          kazmax.speak(data, text: "新宿の天気: #{weather_shinjuku}")
          kazmax.speak(data, text: "鎌倉の天気: #{weather_kamakura}")
        end
      end
    end

    if data['text'] =~ /こんにちは/
      text = ["ご機嫌はいかがかな？<@#{data['user']}>さん", "おほほほほ", "<@#{data['user']}>さん､こんにちはー", "これ#{KAZMAX}､返事をしなさい"].sample
      kazmax.speak(data, text: text)
    end

    if data['text'] =~ /おはよう/
      text = ["おはようあなた♡","おはよー<@#{data['user']}>❗", "<@#{data['user']}>たんおっは〜♪", "<@#{data['user']}>､今日はいい一日になりますよ"].sample
      kazmax.speak(data, text: text)
    end

    if data['text'] =~ /ご招待/
      kazmax.speak(data, text: "チャネル登録はこちら\n https://kaz-max.herokuapp.com/")
    end
  end

  ws.on :close do |event|
    p [:close, event.code]
    ws = nil
    EM.stop
  end

end
