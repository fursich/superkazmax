require 'http'
require 'json'
require 'rest-client'
require 'nokogiri'
require 'faye/websocket'
require 'eventmachine'

KAZMAX = '<@U579AK65C>'.freeze
SUPERKAZMAX = '<@U5THEG8UA>'.freeze
HALL_OF_KAZMAX = 'C5V0WKG90'.freeze
URL_MASA = 'http://jigokuno.com/cid_13.html?p='.freeze  # p=5くらいまである
URL_TENKI = {
  "八幡平" => "http://www.tenki.jp/forecast/2/6/3310/3214-daily.html",
  "新宿"   => "http://www.tenki.jp/forecast/3/16/4410/13104-daily.html",
  "鎌倉"   => "http://www.tenki.jp/forecast/3/17/4610/14204-daily.html",
}

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

  def speak(data=nil, text: nil, with_rate: 1.0)
    return if data.nil?
    if with_rate < 1.0
      return false if rand(0.0..1.0) > with_rate
    end
    post(text: text, channel: data['channel'])
    true
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
    Regexp.union(/kazmax/, /カズマ/, /一真/, /かずま/) # 名前に反応
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

@horesase_words = []

1.upto 21 do |page|
  request = RestClient.get("#{URL_MASA}#{page}")
  doc = Nokogiri::HTML.parse(request.body)
  pics = doc.xpath('//div[@class="article-body"]//img[@src]')
  pics.each do |node|
    @horesase_words << [node.attribute('src').value(), node.attribute('alt').value()]
  end
end

class Tenki
  def initialize(area, url)
    @area = area
    @url = url
  end

  def page
    request = RestClient.get(@url)
    Nokogiri::HTML.parse(request.body)
  end

  def weather_of_day
    wd = page.xpath('//div[@id="townLeftOneBox"]//div[@class="weatherIconFlash"]//img')
    wd.attribute('title').value()
  end

  def precips
    result = {}
    prcs = page.xpath('//div[@id="townLeftOneBox"]//div[@id="precip-table"]//tr[@class="rainProbability"]/td')
    timeslot.zip(prcs).each do |t, precip|
      result[t] = precip.text unless precip.text == '---'
    end
  end

  def comment
    text = ["今日の#{@area}の天気は#{weather_of_day}のようですね｡\n"]
    text << ["降水確率はこのように出ています｡\n"]
    precips.each do |tm, precip|
      text << "#{tm}時: #{precip}\n"
    end
    text.join
  end

  def timeslot
    %w(
    00-06
    06-12
    12-18
    18-24
    )
  end
end

@tenki = {}
URL_TENKI.each do |area, url|
  @tenki[area] = Tenki.new(area,url)
end

kazmax_version = 0.5

kazmax_commands = <<-'EOS'

  直接メンションするか､名前を呼んでみてください｡

  ◯日常会話に答えます(カズマ､一真､kazmaxという語彙に反応)
    おはよう
    こんにちは
    こんばんは
    おやすみ
    ありがとう
    名前は             ･･･ 名前とか
    何も該当しない     ･･･ 適当な絵文字を返す

  ◯いくつかの質問には執事機能を発揮します
    天気               ･･･ 八幡平､鎌倉､新宿の天気を列挙します
    ◯◯の天気         ･･･ 場所を絞りこんで表示する
    ご招待             ･･･ チャネルへの招待方法など
    (ハイパーリンク)   ･･･ 保管用チャネル(#hall_of_kazmax)にリンクを保存

    ヘルプ or 使い方   ･･･ 使い方
    バージョン         ･･･ バージョン

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

      if kazmax.called?(data['text']) # 呼びかけに反応
        if data['text'] =~ /こんにちは/
          text = ["ナマステ", "ご機嫌はいかがかな？<@#{data['user']}>さん", "おほほほほ", "<@#{data['user']}>さん､こんにちはー", "これ#{KAZMAX}､返事をしなさい"].sample
          kazmax.speak(data, text: text)
        elsif data['text'] =~ /もうかりまっか/
          text = ["ぼちぼちでんな"].sample
          kazmax.speak(data, text: text)
        elsif data['text'] =~ /ごめん/
          text = ["こちらこそごめんなさい", "いいんだベイビー", "気にするなよブラザー", "どんまい", "ファンタ買ってこい"].sample
          kazmax.speak(data, text: text)
        elsif data['text'] =~ /おはよう/
          text = ["おはよう あ･な･た♡", "ひゅーひゅー", "おはよー<@#{data['user']}>❗", "<@#{data['user']}>たんおっは〜♪", "<@#{data['user']}>､今日はいい一日になりますよ"].sample
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
        elsif data['text'] =~ /おつかれ/
          text = ["おつかれさま あ･な･た♡", "<@#{data['user']}>さん､頑張りましたね", "おつかれさまです❗", "<@#{data['user']}>さん､そろそろメンタリングしますか？"].sample
          kazmax.speak(data, text: text)
        elsif data['text'] =~ /お名前は/
          text = ['kazmax','スーパーkazmax',"#{KAZMAX}に聞いてください",'エリーツ最高','名乗るほどのものではありません'].sample
          kazmax.speak(data, text: text)

        elsif data['text'] =~ /イケメン|モテメン|カッコイイ|オトコマエ|口説いて|抱いて|惚れ|ほれ|かっこいい|好き|男前|ステキ|素敵|ハンサムモテ男|女好き|女たらし/
          words = @horesase_words.sample
          kazmax.speak(data, text: words[0])
          # kazmax.speak(data, text: words[1])

        elsif data['text'] =~ /<(https:\/\/kaz-max.slack.com\/archives\/.+)>/ # Slack内のコメントリンク
          text = ['エエ話や〜', 'これはいいこと言っている', '微妙な発言ですがいいでしょう･･', '承知いたしました' ].sample
          kazmax.speak(data, text: text)
          kazmax.archive(text: "#{$1}")
        elsif data['text'] =~ /<(https?:\/\/.+)>/ # slack内ではない記事
          text = ['ふむふむ良記事', 'おっこれは', 'りょ', 'すぽぽぽぽぽぽぽーん❗' , '保管します'].sample
          kazmax.speak(data, text: text)
          kazmax.archive(text: "#{$1}")
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
              kazmax.speak(data, text: @tenki['新宿'].comment)
            end
            if target_place =~ /八幡平/
              kazmax.speak(data, text: @tenki['八幡平'].comment)
            end
            if target_place =~ /鎌倉/
              kazmax.speak(data, text: @tenki['鎌倉'].comment)
            end
            if !target_place =~ /新宿|八幡平|鎌倉/
              if target_place.nil?
                kazmax.speak(data, text: "？？")
              else
                text = ["#{target_place}ってどこでしょう", "#{target_place}？", "しらんがな", "地震･雷･火事･オヤジ"].sample
                kazmax.speak(data, text: text)
              end
            end
          else
            kazmax.speak(data, text: "八幡平の天気: #{weather_iwate}")
            kazmax.speak(data, text: "新宿の天気: #{weather_shinjuku}")
            kazmax.speak(data, text: "鎌倉の天気: #{weather_kamakura}")
          end
        else
          text = ['呼びました？', '(ニヤニヤ)', "<@#{data['user']}>さん･･", "にゃーん❗", "す､す､す､すぽぽぽぽぽぽぽーん"].sample
          kazmax.speak(data, text: text, with_rate: 0.05)
          random_emoji = emoji.keys[rand(0..emoji.size-1)] # 絵文字をランダムに選ぶ
          kazmax.speak(data, text: ":#{random_emoji}:")
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
