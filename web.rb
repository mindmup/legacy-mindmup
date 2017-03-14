require 'pp'
require 'sinatra'
require 'uuid'
require 'aws-sdk'
require 'base64'

require File.dirname(__FILE__)+'/lib/s3_policy_signer.rb'
require File.dirname(__FILE__)+'/lib/browser_detection.rb'
require File.dirname(__FILE__)+'/lib/github_routes.rb'
require File.dirname(__FILE__)+'/lib/dropbox_routes.rb'
require 'net/http'


def cache_last_news
  if settings.online && !test? then
    news = Net::HTTP.get(URI(ENV['NEWS_URL'] || 'http://blog.mindmup.com/feeds/posts/default?max-results=1' ))
    news =~ /<entry><id>([^<]*)<.*<title[^>]*>([^<]*)</
    set :last_news_id, $1
    set :last_news_title, $2
  end
end
configure do
  static_ts = '20161111155712'
  public_host = ENV['PUBLIC_HOST'] || 'http://0.0.0.0:5000'
  set :earliest_supported_ios_version, (ENV["EARLIEST_IOS_VERSION"] && ENV["EARLIEST_IOS_VERSION"].to_f) || 1
  set :static_host, "#{public_host}/#{static_ts}"
  set :static_image_host, "#{public_host}/img"
  set :google_analytics_account, ENV["GOOGLE_ANALYTICS_ACCOUNT"]
  set :s3_website,ENV['S3_WEBSITE']
  set :base_url, ENV['SITE_URL'] || "/"
  set :embed_base_url, ENV['EMBED_URL'] || settings.base_url
  set :s3_key_id, ENV['S3_KEY_ID']
  set :s3_form_expiry, (60*60*24*30)
  set :s3_bucket_name, ENV['S3_BUCKET_NAME']
  set :s3_secret_key, ENV['S3_SECRET_KEY']
  set :s3_upload_folder, ENV['S3_UPLOAD_FOLDER']
  set :default_map, ENV['DEFAULT_MAP']|| "map/default"
  set :s3_max_upload_size, ENV['MAX_UPLOAD_SIZE']||100
  set :max_upload_size, ENV['MAX_UPLOAD_SIZE']||100
  set :key_id_generator, UUID.new
  set :current_map_data_version, ENV['CURRENT_MAP_DATA_VERSION'] || "a1"
  set :network_timeout_millis, ENV['NETWORK_TIMEOUT_MILLIS']||10000
  set :publishing_config_url, '/publishingConfig'
  set :async_scripts, '//www.google-analytics.com/ga.js'
  set :online, "offline" != ENV['OFFLINE']
  set :paypal_recipient, ENV['PAYPAL_ID']
  set :paypal_url, ENV['PAYPAL_URL']
  set :paypal_return_url, ENV['PAYPAL_RETURN_URL']
  set :gold_api_url, ENV['GOLD_API_URL']
  set :gold_bucket_name, ENV['GOLD_BUCKET_NAME']
  set :discover_mindmup_host, ENV['DISCOVER_MINDMUP_HOST'] || 'http://discover.mindmup.com'
  AWS.config(:access_key_id=>settings.s3_key_id, :secret_access_key=>settings.s3_secret_key)
  s3=AWS::S3.new()
  set :s3_bucket, s3.buckets[settings.s3_bucket_name]
  set :root, File.dirname(__FILE__)
  set :static, true
  Rack::Mime::MIME_TYPES['.mup'] = 'application/json'
  Rack::Mime::MIME_TYPES['.mm'] = 'text/xml'
  set :protection, :except => [:frame_options, :http_origin], :origin_whitelist => [ENV['SITE_URL']]
  set :last_news_id, ""
  set :last_news_title, ""
  set :gold_pdf_max_size, ENV['GOLD_PDF_MAX_SIZE'] || 100*1024*1024
  if production? then
    require File.dirname(__FILE__) +'/compiled_ts.rb'
    set :public_url, "#{public_host}/compiled/#{settings.compiled_ts}"
  else
    set :public_url, ''
  end
  cache_last_news
end
get '/' do
  show_map
end
get '/legal/privacy' do
  erb :privacy
end
get '/legal/atlas' do
  erb :atlas_terms
end
get '/gd' do
  begin
    state = params[:state] && JSON.parse(params[:state])
    if !state || state['action']=='create' then
      mapid = "new-g"
      erb :google_create 
    else
      mapid = "g1" + state['ids'][0]
      redirect "/#m:"+mapid
    end
  rescue Exception=>e
    puts e
    halt 400, "Google drive state missing or invalid"
  end
end
get '/fb' do
	redirect "http://facebook.com/mindmupapp"
end
get '/default' do
  redirect "/#m:new"
end
get "/s3/:mapid" do
  redirect "/#m:#{params[:mapid]}"
end

get %r{/embedded/(.*)} do |mapid|
  @mapid = mapid
  erb :embedded
end
get %r{/map/(.*)} do |mapid|
  redirect "/#m:#{URI::encode(mapid)}"
end
get "/static" do
  erb :static_map_view
end

get "/m" do
  show_map
end
post "/publishingConfig" do
  s3_upload_identifier = settings.current_map_data_version +  settings.key_id_generator.generate(:compact)
  s3_key=settings.s3_upload_folder+"/" + s3_upload_identifier + ".json"
  s3_content_type="text/plain"
  signer=S3PolicySigner.new
  @policy=signer.signed_policy settings.s3_secret_key, settings.s3_key_id, settings.s3_bucket_name, s3_key, settings.s3_max_upload_size*1024, s3_content_type, settings.s3_form_expiry, "public-read"
  @policy[:upload_identifier] = s3_upload_identifier
  erb :s3UploadConfig
end

get %r{/browserok/?(.*)} do |mapid|
  session['browserok']=true
  redirect "/#m:#{mapid}"
end

get "/un" do
  erb :unsupported
end

get '/cache_news' do
  cache_last_news
  "OK "+settings.last_news_id
end


get '/ios/map' do
  # used for ios version < 3.0
  erb :"ios/3/ios_legacy"
end

get '/ios/editor/:my_app_version' do
  version = 1
  version = params[:my_app_version].to_f if params[:my_app_version]
  halt 404 if version < settings.earliest_supported_ios_version
  if version < 4 then
    erb :"ios/3/ios"
  else
    erb :"ios/4/ios"
  end
end

get '/ios/config' do
  content_type 'text/json'
  config = {
    anonymousPostUrl: "http://#{settings.s3_website}/",
    anonymousFolder: "http://#{settings.s3_website}/#{settings.s3_upload_folder}/",
    publishingConfigUrl: "#{settings.base_url}publishingConfig",
    sharingUrl: "#{settings.base_url}#m:",
    goldApiUrl: "#{settings.gold_api_url}/",
    goldFileUrl: "https://#{settings.gold_bucket_name}.s3.amazonaws.com/",
    static_host: settings.static_host,
    public_url: settings.public_url,
    help_url: "#{settings.discover_mindmup_host}/guide_ios/APP_VERSION/CURRENT_HELP_VERSION"
  }
  halt 200, config.to_json
end


get '/trouble' do
  erb :trouble
end

include MindMup::GithubRoutes
include MindMup::DropboxRoutes
include Sinatra::UserAgentHelpers
helpers do
  def cors_headers
    headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Headers'] = 'accept, authorization, origin'
  end
  def show_map
    if (browser_supported? || user_accepted_browser?)
      erb :editor
    else
      response.headers['Cache-Control'] = 'no-cache, no-store, must-revalidate'
      response.headers['Pragma'] = 'no-cache'
      response.headers['Expires'] = '0'
      erb :unsupported
    end
  end
  def user_accepted_browser?
    !(session["browserok"].nil?)
  end
  def browser_supported?
    browser.chrome? || browser.gecko? || browser.safari? || browser.ios?
  end
  def json_fail message
    halt %Q!{"error":"#{message}"}!
  end
  def map_key mapid
    (mapid.include?("/") ?  "" : settings.s3_upload_folder + "/") + mapid + ".json"
  end
  def user_cohort
     session["cohort"]= Time.now.strftime("%Y%m%d") if session["cohort"].nil?
     session["cohort"]
  end
  def development_lib optional=''
      files = Dir.entries("#{settings.public_folder}/lib#{optional}").reject{|d| File.extname(d) != '.js' }
      return files.map {|f| "/lib#{optional}/#{f}"}
  end
  def load_prefix
    if (!settings.online) then
      "offline"
    else
      ""
    end
  end
end

