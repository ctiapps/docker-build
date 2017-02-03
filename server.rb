require 'sinatra'
require 'json'
require 'logger'
require 'pp'

webhook_url_prefix=ENV.fetch('WEBHOOK_URL_PREFIX', '')
LOGGER = Logger.new(STDOUT)

set :bind, "0.0.0.0"
set :port, 8000
set :logger, LOGGER

class GitCommit
  attr_reader :webhook, :git_type

  def initialize(user_agent:, webhook:)
    @webhook = webhook

    @git_type = if user_agent =~ /^Bitbucket-Webhooks\/2.0/
      :bitbucket
    elsif user_agent =~ /^GitHub-Hookshot/
      :github
    end

    LOGGER.info "ready to go"

    build if git_type
  end

  def bitbucket?
    git_type == :bitbucket
  end

  def github?
    git_type == :github
  end

  # should return latest commit id in git push
  def commit_id
    return @commit_id if @commit_id

    @commit_id = if bitbucket?
      webhook['push']['changes'].first['commits'].first['hash']
    elsif github?
      webhook['commits'].last['id']
    end
  end

  def url
    return @url if @url

    @url = if bitbucket?
      webhook['push']['changes'].first['commits'].first['links']['html']['href']
    elsif github?
      webhook['commits'].last['url']
    end
  end

  def repository
    url.gsub(/^https:\/\/(github.com|bitbucket.org)\//,'').gsub(/\/commit.+$/, '')
  end

  def builder
    @@builder ||= {}
  end

  def build
    return unless repository == 'andyk74/webhook-test'

    if builder[repository].status
      LOGGER.info "Still building #{repository}"
      return
    end

    LOGGER.info "Start building #{repository}"

    builder[repository] = Thread.start do
      begin
        log = `
          cd /Development/docker/docker-build2 \
          && git fetch \
          && git checkout #{commit_id} \
          && docker-compose stop \
          && docker-compose rm -f \
          && docker-compose build --force-rm --pull \
          && docker-compose up -d
        `
        LOGGER.info "Build log: #{log.split}"
      rescue => e
        LOGGER.error "build error #{e}"
      end
    end
  end
end

before do
  begin
    request.body.rewind
    @params = JSON.parse(request.body.read)
  rescue
    logger.error "Can't parse JSON body"
    @params
  end
end

post "/#{webhook_url_prefix}" do
  # logger.info "POST, params: #{params.inspect}"
  ua = request.env['HTTP_USER_AGENT']
  commit = GitCommit.new user_agent: ua, webhook: params
  logger.info "User agent: #{ua}, commit id: #{commit.commit_id}, url: #{commit.url}, repository: #{commit.repository}"
  nil
end

get /\S*/ do
  nil
end

post /\S*/ do
  nil
end


put /\S*/ do
  nil
end

patch /\S*/ do
  nil
end

delete /\S*/ do
  nil
end

options /\S*/ do
  nil
end

link /\S*/ do
  nil
end

unlink /\S*/ do
  nil
end


