require 'http'
require 'json'
require 'faye/websocket'
require 'eventmachine'

# response = HTTP.post('https://slack.com/api/chat.postMessage', params: {
#   token: ENV['SLACK_API_TOKEN'],
#   channel: "D5T0RN8UR",
#   text: 'うぇーい',
#   as_user: true,
# })
# puts JSON.pretty_generate(JSON.parse(response.body))

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
emoji = rc['emoji']

EM.run do
  ws = Faye::WebSocket::Client.new(url)

  ws.on :open do
    p [:open]
  end

  ws.on :message do |event|
    data = JSON.parse(event.data)
    p [:message, data]

    if data['text'] =~ /kazmax/i
      random_emoji = emoji.keys[rand(0..emoji.size-1)]
      ws.send({
        type: 'message',
        text: ":#{random_emoji}:",
        channel: data['channel'],
        timestamp: data['ts'],
      }.to_json)
    end

    if data['text'] =~ /こんにちは/
      ws.send({
        type: 'message',
        text: "ご機嫌はいかがかな？<@#{data['user']}>さん",
        channel: data['channel'],
      }.to_json)
    end

    if data['text'] =~ /お名前は/
      r = rand(0..10)
      if (r < 3)
        ws.send({
          type: 'message',
          text: "Kaz-max",
          channel: data['channel'],
        }.to_json)
      elsif (r < 7)
        ws.send({
          type: 'message',
          text: "君は誰？",
          channel: data['channel'],
        }.to_json)
      else
        ws.send({
          type: 'message',
          text: "ふふふ",
          channel: data['channel'],
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

    if !data.has_key?('reply_to') && data['subtype'] != "bot_message"
      if data['content'] =~ /@superkazmax/ && data['text'] =~ /アーカイブして|保存して/
        if data['text'] =~ /<(https:\/\/kaz-max.slack.com\/archives\/.+)>/
          ws.send({
            type: 'message',
            text: "エエ話や〜",
            channel: data['channel'],
          }.to_json)
          ws.send({
            type: 'message',
            text: "#{$1}",
            channel: "G5V08JHHQ",
          }.to_json)
        elsif data['text'] =~ /<(https?:\/\/.+)>/
          ws.send({
            type: 'message',
            text: "ふむふむ良記事\n #{$1}",
            channel: data['channel'],
          }.to_json)
        else
          ws.send({
            type: 'message',
            text: "(ニヤニヤ)",
            channel: data['channel'],
          }.to_json)
        end
      end
    end
  end

  ws.on :close do |event|
    p [:close, event.code]
    ws = nil
    EM.stop
  end

end
