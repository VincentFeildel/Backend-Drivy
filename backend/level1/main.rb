require 'json'
require 'date'

# Helpers
def simple_p_calc(car, distance, days)
  price_per_km = car['price_per_km']
  price_per_day = car ['price_per_day']
  rental_price = price_per_km * distance + price_per_day * days
end

def prog_p_calc(car, distance, days)
  price_per_km = car['price_per_km']
  price_per_day = car ['price_per_day']
  case days
    when 1
      price_days = price_per_day
    when 2 .. 4
      price_days = price_per_day + (price_per_day * 0.9 * (days - 1))
    when 5 .. 10
      price_days = price_per_day + (price_per_day * 0.9 * 3) + (price_per_day * 0.7 * (days - 4))
    else
      price_days = price_per_day + (price_per_day * 0.9 * 3) + (price_per_day * 0.7 * 6) + (price_per_day * 0.5 * (days - 10))
  end
  rental_price = price_per_km * distance + price_days
end

def dates_to_days(start_date, end_date)

  days = (Date.parse(end_date) - Date.parse(start_date) + 1).to_i
end

def actions_array(rental_price, fees_h)
  driver_due = rental_price + fees_h[:deductible_reduction]
  insurance_due = fees_h[:insurance_fee]
  assistance_due = fees_h[:assistance_fee]
  drivy_due = fees_h[:drivy_fee] + fees_h[:deductible_reduction]
  owner_due = driver_due - insurance_due - assistance_due - drivy_due
  return [
    {
      "who": "driver",
      "type": driver_due > 0 ? "debit" : "credit",
      "amount": driver_due.abs.to_i
    },
    {
      "who": "owner",
      "type": owner_due > 0 ? "credit" : "debit",
      "amount": owner_due.abs.to_i
    },
    {
      "who": "insurance",
      "type": insurance_due > 0 ? "credit" : "debit",
      "amount": insurance_due.abs.to_i
    },
    {
      "who": "assistance",
      "type": assistance_due > 0 ? "credit" : "debit",
      "amount": assistance_due.abs.to_i
    },
    {
      "who": "drivy",
      "type": drivy_due > 0 ? "credit" : "debit",
      "amount": drivy_due.abs.to_i
    }
  ]
end

def fees_hash(deductible, rental_price, days)
  # Deductible reduction
  deductible_reduction = deductible ? 400 * days : 0

  # Commission details
  insurance_fee = 0.3 * 0.5 * rental_price
  assistance_fee = days * 100
  drivy_fee = 0.3 * 0.5 * rental_price - assistance_fee

  return { deductible_reduction: deductible_reduction, insurance_fee: insurance_fee, assistance_fee: assistance_fee, drivy_fee: drivy_fee }
end

# Main program (levels 1 to 5)
def generate_rental_output(input_path, output_path, price_calc_method = 'simple', price_format = 'short', disp_deductible = false, disp_actions = false)

  input_data = JSON.parse(File.read(input_path))

  output_rentals = []
  input_data['rentals'].each do |rental|
    car = input_data['cars'].find { |car| car['id'] == rental['car_id']}

    # Setting pricing variables
    distance = rental['distance']
    days = dates_to_days(rental['start_date'], rental['end_date'])

    # Calculating price with relevant method
    case price_calc_method
      when 'simple'
        rental_price = simple_p_calc(car, distance, days)
      else
        rental_price = prog_p_calc(car, distance, days)
    end

    # -------Calculating commissions & reductions------------------

    fees_h = fees_hash(rental['deductible_reduction'], rental_price, days)

    # Populating output data
    rental_with_price = { id: rental['id'] }
    if disp_actions
      rental_with_price[:actions] = actions_array(rental_price, fees_h)
    else
      rental_with_price[:price] = rental_price.to_i
      rental_with_price[:options] = { deductible_reduction: fees_h[:deductible_reduction].to_i } if disp_deductible
      rental_with_price[:commission] = {
        insurance_fee: fees_h[:insurance_fee].to_i,
        assistance_fee: fees_h[:assistance_fee].to_i,
        drivy_fee: fees_h[:drivy_fee].to_i
        } if price_format == 'full'
    end

    output_rentals << rental_with_price
  end

  File.open(output_path, 'wb') do |file|
    file.write(JSON.generate( { rentals: output_rentals } ))
  end
end

# Level 6 program

def modification_output(input_path, output_path)
  # Initialization
  input_data = JSON.parse(File.read(input_path))
  output_hash = {
    rental_modifications: []
  }
  # Looping rental modifications:
  input_data['rental_modifications'].each do |modif|
  rental = input_data['rentals'].find { |rental| rental['id'] == modif['rental_id'] }
  car = input_data['cars'].find { |car| car['id'] == rental['car_id'] }

    # First transaction dates & distance
    distance = rental['distance']
    days = dates_to_days(rental['start_date'], rental['end_date'])
    rental_price = prog_p_calc(car, distance, days)
    # First transaction action array
    deductible = rental['deductible_reduction']
    prev_action_array = actions_array(rental_price, fees_hash(deductible, rental_price, days))

    # ----------------------------------------------------

    # Second transaction dates & distance
    distance = modif['distance'].nil? ? distance : modif['distance']
    start_date = modif['start_date'].nil? ? rental['start_date'] : modif['start_date']
    end_date = modif['end_date'].nil? ? rental['end_date'] : modif['end_date']
    days_new = dates_to_days(start_date, end_date)

    # Price variation new transaction (total)
    rental_price_diff = prog_p_calc(car, distance, days_new) - rental_price
    # Price variation new transaction (detailed)
    days_diff = days_new - days
    diff_action_array = actions_array(rental_price_diff, fees_hash(deductible, rental_price_diff, days_diff))

    # Recording rental modification with price variation
    rental_modification = {
      "id": modif['id'],
      "rental_id": modif['rental_id'],
      "actions": diff_action_array
    }
    output_hash[:rental_modifications] << rental_modification
  end
  File.open(output_path, 'wb') do |file|
    file.write(JSON.generate(output_hash))
  end
end


# ________________________________________________________________
# ________________________________________________________________

# Generating output files for each level:

# LEVEL 1
input_path = 'data.json'
output_path = 'output.json'

generate_rental_output(input_path, output_path)

# LEVEL 2
input_path = '../level2/data.json'
output_path = '../level2/output.json'

generate_rental_output(input_path, output_path, 'prog')

# LEVEL 3
input_path = '../level3/data.json'
output_path = '../level3/output.json'

generate_rental_output(input_path, output_path, 'prog', 'full')

# LEVEL 4
input_path = '../level4/data.json'
output_path = '../level4/output.json'

generate_rental_output(input_path, output_path, 'prog', 'full', true)

# LEVEL 5
input_path = '../level5/data.json'
output_path = '../level5/output.json'

generate_rental_output(input_path, output_path, 'prog', 'full', true, true)

# LEVEL 6
input_path = '../level6/data.json'
output_path = '../level6/output.json'

modification_output(input_path, output_path)
