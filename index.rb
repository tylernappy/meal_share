require 'sinatra'
require 'httmultiparty'
require 'debugger' if Sinatra::Base.development?
require 'open-uri'
require 'mini_magick'
require 'twilio-ruby'
require 'dotenv'
require "aws/s3"
require 'active_record'
require 'sinatra/activerecord'
# require './environments'
require 'bcrypt'
require 'htmlentities'

require './text_flow/receive_receipt_and_send_breakdown.rb'

set :port, 8085
Dotenv.load
$numbers = ["0","1","2","3","4","5","6","7","8","9", "I", "?"]
$decimals = [".", ":", " "]
$letters = ('a'..'zz').to_a
$app_phone_number = "+15164505983"
$correct_breakdown_string = "\n
Here is the breakdown of your meal.\n\n
#######\n
If you would like to add a missing item, text the name of item, followed by a colon, followed by the price of the item.  If there is more than one missing items, place each missing item on a new line.  Here is an example:\n\n
Pasta:10.00\n\n
#######\n
If you would like to correct an item's price, type it's letter assignment, followed by colon, followed by it's correct price.  Here is an example:\n\n
a:6.00\n\n
#######\n
If you would like to correct an item's name, type it's letter assignment, followed by colon, followed by it's correct name.  Here is an example:\n\n
a:Meatloaf\n\n
#######\n
If you would like to correct BOTH an item's price and name, type it's letter assignment, followed by colon, followed by it's correct name, followed by a colon, followed by it's correct price.  Here is an example:\n\n
a:Coffee:6.00\n\n
#######\n
If there are multiple entries to correct, place the next item on a new line:\n\n
Steak:20.00\n
g:7.50\n
a:Ice Cream\n
g:Hamburger:7.50\n
After sending all of you corrections, send an OK to this number.
"

class MealShare < Sinatra::Base
   register Sinatra::ActiveRecordExtension
end

class Meal < ActiveRecord::Base
   has_many :eaters, dependent: :destroy
   has_many :dishes, dependent: :destroy
end

class Eater < ActiveRecord::Base
   has_many :dishes, dependent: :destroy
   belongs_to :meal
end

class Dish < ActiveRecord::Base
   belongs_to :eaters
   belongs_to :meal
end

#Initiate Twilio Client
$client = Twilio::REST::Client.new ENV['account_sid'], ENV['auth_token']

post "/" do
   params = JSON.parse(request.body.read) #if using curl
   puts "Text received from #{params['From']}"
   meal = Meal.where(params['From'])
   if meal.empty?
      received_receipt_and_send_breakdown(params)
   else
      if meal.sent_breakdown == true && meal.corrected_breakdown.nil? && meal.confirmed_breakdown.nil? && meal.received_names_of_eaters.nil? && meal.received_all_eaters_dishes.nil? && meal.confirmed_all_dishes.nil? && meal.sent_total.nil?
         correct_breakdown(params)
      # elsif  meal.sent_breakdown == true && meal.corrected_breakdown == true && meal.confirmed_breakdown.nil? && meal.received_names_of_eaters.nil? && meal.received_all_eaters_dishes.nil? && meal.confirmed_all_dishes.nil? && meal.sent_total.nil?
      #
      # elsif  meal.sent_breakdown == true && meal.corrected_breakdown == true && meal.confirmed_breakdown == true && meal.received_names_of_eaters.nil? && meal.received_all_eaters_dishes.nil? && meal.confirmed_all_dishes.nil? && meal.sent_total.nil?
      #
      # elsif  meal.sent_breakdown == true && meal.corrected_breakdown == true && meal.confirmed_breakdown == true && meal.received_names_of_eaters == true && meal.received_all_eaters_dishes.nil? && meal.confirmed_all_dishes.nil? && meal.sent_total.nil?
      #
      # elsif  meal.sent_breakdown == true && meal.corrected_breakdown == true && meal.confirmed_breakdown == true && meal.received_names_of_eaters == true && meal.received_all_eaters_dishes == true && meal.confirmed_all_dishes.nil? && meal.sent_total.nil?
      #
      # elsif  meal.sent_breakdown == true && meal.corrected_breakdown == true && meal.confirmed_breakdown == true && meal.received_names_of_eaters == true && meal.received_all_eaters_dishes == true && meal.confirmed_all_dishes == true && meal.sent_total.nil?
      #
      # elsif  meal.sent_breakdown == true && meal.corrected_breakdown == true && meal.confirmed_breakdown == true && meal.received_names_of_eaters == true && meal.received_all_eaters_dishes == true && meal.confirmed_all_dishes == true && meal.sent_total == true

      end
   end
   debugger
   debugger
end

def received_receipt_and_send_breakdown params
   response = HTTParty.get("https://api.idolondemand.com/1/api/sync/ocrdocument/v1?url=#{URI.encode(params["MediaUrl0"])}&apikey=81b77cb6-88ce-42ec-bea0-eca4c98405c6")
   string = HTMLEntities.new.decode(response.parsed_response["text_block"].first["text"])
   items = analyze_receipt_text(string)
   meal = save_initial_meal_instance(params['From'], items)
   items_string = format_items_for_text(meal)
   $client.messages.create(from: $app_phone_number, to: meal.phone_number, body: items_string) ## send items
   $client.messages.create(from: $app_phone_number, to: meal.phone_number, body: $correct_breakdown_string)
end

def format_items_for_text (meal)
   string = ""
   dishes = meal.dishes
   dishes.each do |dish|
      string << "\n#{dish.bin_key} : #{dish.item} : $#{dish.price}"
   end
   return string
end

string = "Lnluss\n. @\n\"ixi'i;i&5 V NG\nLONE'S HONE CENTERS LLC\nzoo n1seLE£ uR1vÉ\nGARDEN CITY, NY 11530 (516) ?94-653I\n* SALE -\nSNLESN: FSILANEI 13 TRANSN: 5204425 11-28-14\nI58890 IsA I25V NHITE GFCI I2 58\n104033 IsA I20V WHITE sF DECO 5N 4:96\n2 O 2.48\nX\n802?I 2-GANG WALL PLATE TF262NC 1 58\n1*\n356351 7 DAY BASIC PROGRANHABLE 34:98\n49.99 DISCOUNT EACH -I5.OI\n344556 FS 2-LIGHT BN FALLSBROOK I5.97\n17.97 DISCOUNT EACH -2.00\n28630 BATH DRAIN 2OGA TRIFLEVER 58.99\nSUBTOTAL: I29.06\nINN: I1.13\nW TOTNL: NBAS\nVISA: NBAS\nI; *,:1 .\"NT; 1Ll7..()\"1.\n;;;NHOUNT:I4O.19 NUTNCD:DO79BB\né;CIL•!•.,. ; is 11/28/ IN ,14 ;53159\nAM f ' ! *\n;\"T, €; 11/28714 14:54:06\nPURCHASED: 7\nIN S AND SPECIAL ORDER ITEMS\nIT INTINlNNI\n1"
