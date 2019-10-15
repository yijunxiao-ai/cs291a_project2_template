require 'sinatra'
require 'digest'
require 'json'
require 'google/cloud/storage'
storage = Google::Cloud::Storage.new(project_id: 'cs291-f19')
bucket = storage.bucket 'cs291_project2', skip_lookup: true

get '/' do
  status 302
  redirect to('/files/')
end

get '/files/' do
  digests = []
  files = bucket.files
  files.all do |file|
    digest = gcpath2digest(file.name)
    if is_valid_digest(digest)
      digests.push(digest)
    end
  end
  content_type :json
  digests.to_json
end

post '/files/' do
  if params[:file].is_a?(Hash)
    filepath = params[:file][:tempfile].path
    # file not exists
    if !File.file?(filepath)
      halt 422
    # file size too large
    elsif File.size(filepath) > 1024 * 1024
      halt 422
    else
      digest = get_digest(filepath)
      files = bucket.files
      files.all do |file|
        if digest == gcpath2digest(file.name)
          halt 409
        end
      end
      # upload file
      bucket.create_file filepath, digest2gcpath(digest),
                         content_type: params[:file][:type]
      halt 201, {'Content-Type' => 'application/json'}, {'uploaded' => digest}.to_json
    end
  # file not specified
  else
    halt 422
  end
end

get '/files/:digest' do |digest|
  digest = digest.downcase
  if !is_valid_digest(digest)
    halt 422
  else
    files = bucket.files
    files.all do |file|
      if digest == gcpath2digest(file.name)
        header = {'Content-Type' => file.content_type}
        downloaded = file.download
        downloaded.rewind
        body = downloaded.read
        halt 200, header, body
      end
    end
    halt 404
  end
end

delete '/files/:digest' do |digest|
  digest = digest.downcase
  if !is_valid_digest(digest)
    halt 422
  else
    files = bucket.files
    files.all do |file|
      if digest == gcpath2digest(file.name)
        file.delete
      end
    end
    halt 200
  end
end


helpers do
  def get_digest(filepath)
    return Digest::SHA256.hexdigest File.read filepath
  end

  def digest2gcpath(digest)
    digest[0, 2] << "/" << digest[2, 2] << "/" << digest[4, 60]
  end

  def gcpath2digest(gcpath)
    gcpath[0, 2] << gcpath[3, 2] << gcpath[6, 60]
  end

  def is_valid_digest(digest)
    if digest.length == 64 && !digest[/\H/]
      return true
    else
      return false
    end
  end
end
    
