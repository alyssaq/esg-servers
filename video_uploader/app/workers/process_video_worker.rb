class ProcessVideoWorker
  include Sidekiq::Worker

  def perform(title, description, folder_name)
    cwd_path = ENV['UPLOAD_FOLDER']
    result = `cd #{cwd_path} && ./multinorm.sh #{folder_name}`

    puts result

    UploadVideoWorker.perform_async(title, description, folder_name)
  end
end
