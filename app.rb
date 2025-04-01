require 'sinatra'
require 'json'
require 'csv'
require 'time'

enable :sessions

# Méthode pour charger les versets
def load_verses
  file = File.read('bible.json')
  JSON.parse(file)
end

# Méthode pour enregistrer les demandes de prière
def save_prayer_request(data)
  file_path = 'requests.json'
  if File.exist?(file_path)
    file = File.read(file_path)
    existing_data = file.empty? ? [] : JSON.parse(file)
  else
    existing_data = []
  end
  existing_data << data
  File.write(file_path, JSON.pretty_generate(existing_data))
end

# Route d'accueil
get '/' do
  erb :index
end

# Route pour générer et afficher un verset
post '/verse' do
  # Vérifier si un verset a déjà été délivré dans les 24h
  if session[:last_verse_time]
    last_time = Time.parse(session[:last_verse_time])
    if Time.now - last_time < 24*60*60
      @message = "Vous avez déjà reçu un verset dans les dernières 24 heures. Veuillez réessayer plus tard."
      return erb :limit_reached
    end
  end

  @user_name = params[:name].strip.empty? ? "Invité" : params[:name]
  @phone_number = params[:number]

  verses = load_verses
  @verse = verses.sample

  session[:last_verse_time] = Time.now.to_s

  erb :verse
end

# Route pour traiter le formulaire du sujet de prière
post '/prayer' do
  user_name = params[:name]
  phone_number = params[:number]
  prayer_subject = params[:prayer]

  save_prayer_request({
    name: user_name,
    phone: phone_number,
    prayer: prayer_subject,
    submitted_at: Time.now
  })

  erb :thank_you
end

# Route pour exporter les demandes en CSV
get '/export.csv' do
  content_type 'application/csv'
  attachment "prayer_requests.csv"

  if File.exist?('requests.json')
    data = JSON.parse(File.read('requests.json'))
  else
    data = []
  end

  csv_string = CSV.generate(headers: true) do |csv|
    csv << ["Nom", "Téléphone", "Sujet de prière", "Date de soumission"]
    data.each do |request|
      csv << [
        request["name"],
        request["phone"],
        request["prayer"],
        request["submitted_at"]
      ]
    end
  end

  csv_string
end
