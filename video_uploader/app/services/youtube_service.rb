require 'google/api_client'

class YoutubeService
  YOUTUBE_API_SERVICE_NAME = "youtube"
  YOUTUBE_API_VERSION = "v3"

  def retrieve_playlist(playlist_id)
    items = []

    next_page_token = ''
    until next_page_token.nil?
      opts = {
        part: 'snippet',
        maxResults: 50,
        playlistId: playlist_id,
        pageToken: next_page_token
      }
      api_response = api_client.execute!(api_method: youtube.playlist_items.list, parameters: opts)
      api_response.data.items.each do |playlist_item|
        if playlist_item.snippet.thumbnails.present?
          item = {
            video_id: playlist_item.snippet.resourceId.videoId,
            title: playlist_item.snippet.title,
            published_at: playlist_item.snippet.publishedAt,
            description: playlist_item.snippet.description,
            image1: playlist_item.snippet.thumbnails.default.url,
            image2: playlist_item.snippet.thumbnails.medium.url,
            image3: playlist_item.snippet.thumbnails.high.url
          }
          items << item
        end
      end

      next_page_token = api_response.next_page_token
    end

    items
  end

  def fetch_playlist_details(playlist_id)
    opts = {
      part: 'snippet',
      id: playlist_id
    }
    api_response = api_client.execute!(api_method: youtube.playlists.list, parameters: opts)

    api_response.data.items.first unless api_response.data.items.empty?
  end

  def get_video(video_id)
    opts = {
      part: 'snippet',
      id: video_id
    }
    api_response = api_client.execute!(api_method: youtube.videos.list, parameters: opts)
    video_item = api_response.data.items.first

    Episode.new(
      video_site: 'youtube',
      video_id: video_id,
      title: video_item.snippet.title,
      published_at: video_item.snippet.publishedAt,
      description: video_item.snippet.description,
      image1: video_item.snippet.thumbnails.default.url,
      image2: video_item.snippet.thumbnails.medium.url,
      image3: video_item.snippet.thumbnails.high.url
    )
  end

  def fetch_video_stats(video_ids=[])
    video_ids_string = video_ids.join(',')

    opts = {
        part: 'statistics',
        id: video_ids_string,
        maxResults: 50
    }
    api_response = api_client.execute!(api_method: youtube.videos.list, parameters: opts)

    api_response.data.items
  end

  def upload_video(options={})
    Faraday.default_adapter = :httpclient
    Faraday::Response.register_middleware(gzip: Faraday::Response::Middleware)

    body = {
        snippet: {
            title: options[:title],
            description: options[:description],
            categoryId: '28'
        },
        status: {
            privacyStatus: 'public',
            license: 'creativeCommon'
        }
    }

    videos_insert_response = api_client.execute!(
        api_method: youtube.videos.insert,
        body_object: body,
        media: Google::APIClient::UploadIO.new(options[:file], 'video/*'),
        parameters: {
            uploadType: 'resumable',
            part: body.keys.join(',')
        }
    )

    videos_insert_response.resumable_upload.send_all(api_client)

    videos_insert_response
  end

  def add_to_playlist(options={})
    body = {
        snippet: {
            playlistId: options[:playlist_id],
            resourceId: {
                kind: 'youtube#video',
                videoId: options[:video_id],
                categoryId: '28'
            }
        }
    }

    playlist_item_insert_response = api_client.execute!(
        api_method: youtube.playlist_items.insert,
        body_object: body,
        parameters: {
            part: body.keys.join(',')
        }
    )

    playlist_item_insert_response
  end

  def update_video(options={})
    body = {
        id: options[:id],
        snippet: {
            title: options[:title],
            description: options[:description],
            categoryId: '28',
        },
        status: {
            license: 'creativeCommon',
        }
    }

    video_update_response = api_client.execute!(
        api_method: youtube.videos.update,
        body_object: body,
        parameters: {
            part: body.keys.join(',')
        }
    )

    video_update_response
  end

  private

  def authorization
    @authorization ||= GoogleAuthService.new.client(access_token: ENV['YOUTUBE_ACCESS_TOKEN'], refresh_token: ENV['YOUTUBE_REFRESH_TOKEN']).tap do |client|
        client.refresh!
      end
  end

  def api_client
    @google_api_client ||= Google::APIClient.new(authorization: authorization, application_name: 'Engineers.SG', application_version: '1.0.0')
  end

  def youtube
    @youtube_api ||= api_client.discovered_api(YOUTUBE_API_SERVICE_NAME, YOUTUBE_API_VERSION)
  end
end
