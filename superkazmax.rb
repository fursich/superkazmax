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

  def called?(text)
    mentioned?(text) || named?(text)
  end

  def mentioned?(text)
    text =~ /#{SUPERKAZMAX}/
  end

  def named?(text)
    text =~ aggregate_name
  end

  def aggregate_name
    Regexp.union(/kazmax/, /カズマ/, /一真/ ) # 名前に反応
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

kazmax_version = 0.3

kazmax_commands = <<-'EOS'

  直接メンションするか､名前を呼んでみてください｡

  @superkazmax (メンション)で執事機能を発揮します
    天気               ･･･ 八幡平､鎌倉､新宿の天気を列挙します
    ◯◯の天気         ･･･ 場所を絞りこんで表示する
    ご招待             ･･･ チャネルへの招待方法など
    (ハイパーリンク)   ･･･ 保管用チャネル(#hall_of_kazmax)にリンクを保存
    ヘルプ or 使い方   ･･･ 使い方
    バージョン         ･･･ バージョン

  名前をよぶと日常会話に答えます(カズマ､一真､kazmaxという語彙に反応)
    おはよう
    こんにちは
    こんばんは
    おやすみ
    ありがとう
    名前は             ･･･ 名前とか
    何も該当しない     ･･･ 適当な絵文字を返す
EOS

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

      if kazmax.named?(data['text']) # 呼びかけに反応
        if data['text'] =~ /こんにちは/
          text = ["ご機嫌はいかがかな？<@#{data['user']}>さん", "おほほほほ", "<@#{data['user']}>さん､こんにちはー", "これ#{KAZMAX}､返事をしなさい"].sample
          kazmax.speak(data, text: text)
        elsif data['text'] =~ /おはよう/
          text = ["おはようあなた♡","おはよー<@#{data['user']}>❗", "<@#{data['user']}>たんおっは〜♪", "<@#{data['user']}>､今日はいい一日になりますよ"].sample
          kazmax.speak(data, text: text)
        elsif data['text'] =~ /こんばんは/
          text = ["こんばんは<@#{data['user']}>さん", "こんばんは！", "<@#{data['user']}>さんがんばってますね〜"].sample
          kazmax.speak(data, text: text)
        elsif data['text'] =~ /おやすみ/
          text = ["おやすみ あ･な･た♡", "<@#{data['user']}>さん､良い夢を", "Goodnight♪", "<@#{data['user']}>さん､おやすみなさい"].sample
          kazmax.speak(data, text: text)
        elsif data['text'] =~ /ありがとう/
          text = ["こちらこそ♡", "サマサマ〜", "<@#{data['user']}>さん､いつも感謝してますよ"].sample
          kazmax.speak(data, text: text)
        elsif data['text'] =~ /お名前は/
          text = ['kazmax','スーパーkazmax',"#{KAZMAX}に聞いてください",'エリーツ最高','名乗るほどのものではありません'].sample
          kazmax.speak(data, text: text)
        else
          random_emoji = emoji.keys[rand(0..emoji.size-1)] # 絵文字をランダムに選ぶ
          kazmax.speak(data, text: ":#{random_emoji}:")
        end
      end

      if kazmax.mentioned?(data['text']) # 自分宛てのメンションのみ
        if data['text'] =~ /<(https:\/\/kaz-max.slack.com\/archives\/.+)>/ # Slack内のコメントリンク
          text = ['エエ話や〜', 'これはいいこと言っている', '微妙な発言ですがいいでしょう･･', '承知いたしました' ].sample
          kazmax.speak(data, text: text)
          kazmax.archive("#{$1}")
        elsif data['text'] =~ /<(https?:\/\/.+)>/ # slack内ではない記事
          text = ['ふむふむ良記事', 'おっこれは', 'りょ', 'すぽぽぽぽぽぽぽーん❗' , '保管します'].sample
          kazmax.speak(data, text: text)
          kazmax.archive("#{$1}")
        elsif data['text'] =~ /help | ヘルプ | 使い方/i
          kazmax.speak(data, text: kazmax_commands)
        elsif data['text'] =~ /version | バージョン/i
          kazmax.speak(data, text: "#{kazmax_version}")
        elsif data['text'] =~ /ご招待/
          kazmax.speak(data, text: "チャネル登録はこちら\n https://kaz-max.herokuapp.com/")
        elsif data['text'] =~ /天気/
          weather_iwate = "http://www.tenki.jp/forecast/2/6/3310/3214-1hour.html"
          weather_shinjuku = "http://www.tenki.jp/forecast/3/16/4410/13104-1hour.html"
          weather_kamakura = "http://www.tenki.jp/forecast/3/17/4610/14204-1hour.html"

          if data['text'] =~ /(.+)の天気/
            target_place = $1
            if target_place =~ /新宿/
              kazmax.speak(data, text: "新宿の天気: #{weather_shinjuku}")
            end
            if target_place =~ /八幡平/
              kazmax.speak(data, text: "八幡平の天気: #{weather_iwate}")
            end
            if target_place =~ /鎌倉/
              kazmax.speak(data, text: "鎌倉の天気: #{weather_kamakura}")
            end
            if !target_place =~ /新宿|八幡平|鎌倉/
              if target_place.nil?
                kazmax.speak(data, text: "？？")
              else
                text = ["#{target_place}ってどこでしょう", "#{target_place}？", "しらんがな", "地震･雷･火事･オヤジ"].sample
                kazmax.speak(data, text: )
              end
            end
          else
            kazmax.speak(data, text: "八幡平の天気: #{weather_iwate}")
            kazmax.speak(data, text: "新宿の天気: #{weather_shinjuku}")
            kazmax.speak(data, text: "鎌倉の天気: #{weather_kamakura}")
          end
        else
          text = ['呼びました？', '華麗にスルー', '(ニヤニヤ)', "<@#{data['user']}>さん･･", "#{kazmax_commands}"].sample
          kazmax.speak(data, text: text)
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
