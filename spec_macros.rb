# *********************************
# ********** SPEC MACROS **********
# *********************************

# ************************************************
#  BATCH ASSIGNMENT SPEC MACROS
# app/spec/support/shift_request_macros.rb
# ************************************************

module ShiftRequestMacros

  # ...

  def filter_shifts_by_time_inclusively
    #set start filter
    select '2011', from: 'filter_start_year'
    select 'January', from: 'filter_start_month'
    select '1', from: 'filter_start_day'
    #set end filter
    select '2017', from: 'filter_end_year'
    select 'January', from: 'filter_end_month'
    select '1', from: 'filter_end_day'
    
    click_button 'Filter'    
  end

  # ...

  def check_batch_assign_uri
    expect(current_path).to eq "/assignment/batch_edit"
    expect(URI.parse(current_url).to_s).to include("&ids[]=#{batch[0].id}&ids[]=#{batch[1].id}&ids[]=#{batch[2].id}")
  end

  def check_uniform_assign_uri
    expect(current_path).to eq "/assignment/batch_edit_uniform"
    expect(URI.parse(current_url).to_s).to include("&ids[]=#{batch[0].id}&ids[]=#{batch[1].id}&ids[]=#{batch[2].id}")
  end

  def check_batch_assign_select_values rider, status
    rider_id_selector = "#wrapped_assignments_fresh__assignment_rider_id"
    status_selector = "#wrapped_assignments_fresh__assignment_status"

    expect(page.within("#assignments_fresh_0"){ find(rider_id_selector).find("option[selected]").text }).to eq rider.name
    expect(page.within("#assignments_fresh_1"){ find(rider_id_selector).find("option[selected]").text }).to eq rider.name
    expect(page.within("#assignments_fresh_2"){ find(rider_id_selector).find("option[selected]").text }).to eq rider.name
    
    expect(page.within("#assignments_fresh_0"){ find(status_selector).find("option[selected]").text }).to eq status
    expect(page.within("#assignments_fresh_1"){ find(status_selector).find("option[selected]").text }).to eq status
    expect(page.within("#assignments_fresh_2"){ find(status_selector).find("option[selected]").text }).to eq status    
  end

  def assign_batch_to rider, status
    3.times do |n|
      page.within("#assignments_fresh_#{n}") do 
        find("#wrapped_assignments_fresh__assignment_rider_id").select rider.name
        find("#wrapped_assignments_fresh__assignment_status").select status
      end
    end
    click_button 'Save changes'
  end

  def check_uniform_assign_shift_list rider, status
    expect(page.within("#shifts"){ find("h3").text }).to eq "Shifts"

    expect(page.all("#shifts_0 .shift_box")[0].text).to eq "#{batch[0].table_time} @ #{restaurant.name}"
    expect(page.all("#shifts_0 .shift_box")[1].text).to eq "Assigned to: #{rider.name} [#{status}]"

    expect(page.all("#shifts_1 .shift_box")[0].text).to eq "#{batch[1].table_time} @ #{restaurant.name}"
    expect(page.all("#shifts_1 .shift_box")[1].text).to eq "Assigned to: #{rider.name} [#{status}]"

    expect(page.all("#shifts_2 .shift_box")[0].text).to eq "#{batch[2].table_time} @ #{restaurant.name}"
    expect(page.all("#shifts_2 .shift_box")[1].text).to eq "Assigned to: #{rider.name} [#{status}]"
  end

  def check_uniform_assign_select_values
    expect(page.within("#assignment_form"){ find("#assignment_rider_id").has_css?("option[selected]") } ).to eq false
    expect(page.within("#assignment_form"){ find("#assignment_status").find("option[selected]").text }).to eq 'Proposed'
  end

  def uniform_assign_batch_to rider, status
    page.find("#assignment_rider_id").select rider.name
    page.find("#assignment_status").select status
    click_button 'Save changes'
  end
  
  def check_assignments_with_conflicts_list conflict_list_indices, batch_indices
    expect(page.within("#assignments_with_conflicts"){ find("h3").text }).to eq "Assignments With Conflicts"
    conflict_list_indices.each_with_index do |i,j|
      batch_index = batch_indices[j]
      expect(page.all("#assignments_with_conflicts_#{i} .shift_box")[0].text).to eq "#{batch[batch_index].table_time} @ #{batch[batch_index].restaurant.name}"
      expect(page.all("#assignments_with_conflicts_#{i} .shift_box")[1].text).to eq "Assigned to: #{other_rider.name} [Proposed]"
      expect(page.all("#assignments_with_conflicts_#{i} .shift_box")[2].text).to eq conflicts[batch_index].table_time
      expect(page.find("#decisions_#{i}_Accept")).to be_checked
      expect(page.find("#decisions_#{i}_Override")).to_not be_checked      
    end
  end

  def check_assignments_with_double_booking_list double_booking_list_indices, batch_indices
    expect(page.within("#assignments_with_double_bookings"){ find("h3").text }).to eq "Assignments With Double Bookings"
    double_booking_list_indices.each_with_index do |i,j|
      batch_index = batch_indices[j]
      expect(page.all("#assignments_with_double_bookings_#{i} .shift_box")[0].text).to eq "#{batch[batch_index].table_time} @ #{batch[batch_index].restaurant.name}"
      expect(page.all("#assignments_with_double_bookings_#{i} .shift_box")[1].text).to eq "Assigned to: #{other_rider.name} [Proposed]"
      expect(page.all("#assignments_with_double_bookings_#{i} .shift_box")[2].text).to eq "#{double_bookings[batch_index].table_time} @ #{double_bookings[batch_index].restaurant.name}"
      expect(page.find("#decisions_0_Accept")).to be_checked
      expect(page.find("#decisions_0_Override")).to_not be_checked      
    end
  end


  def check_without_obstacles_list list_indices, batch_indices
    #input: Array of Nums (indices of assignments_without_obstacles Arr to check for), Array of Nums (indices of batch Shifts Arr to retrieve values from)
    expect(page.within("#assignments_without_obstacles"){ find("h3").text }).to eq "Assignments Without Obstacles"
    list_indices.each_with_index do |i,j|
      batch_index = batch_indices[j]
      expect(page.all("#assignments_without_obstacles_#{i} .shift_box")[0].text).to eq "#{batch[batch_index].table_time} @ #{restaurant.name}"
      expect(page.all("#assignments_without_obstacles_#{i} .shift_box")[1].text).to eq "Assigned to: #{other_rider.name} [Proposed]"      
    end
  end

  def check_reassign_single_shift_list rider, status, batch_index
    expect(page.within("#assignments_requiring_reassignment"){ find("h3").text }).to eq "Assignments Requiring Reassignment"
    expect(page.find("#assignments_requiring_reassignment_0 .shift_box").text).to eq "#{batch[batch_index].table_time} @ #{batch[batch_index].restaurant.name}"
    expect(page.within("#assignments_requiring_reassignment_0"){ 
        find("#wrapped_assignments_fresh__assignment_rider_id").find("option[selected]").text 
      }).to eq rider.name
    expect(page.within("#assignments_requiring_reassignment_0"){ 
        find("#wrapped_assignments_fresh__assignment_status").find("option[selected]").text 
      }).to eq status
  end

  def reassign_single_shift_to rider, status
    page.within("#assignments_requiring_reassignment_0") { find("#wrapped_assignments_fresh__assignment_rider_id").select rider.name }
    page.within("#assignments_requiring_reassignment_0") { find("#wrapped_assignments_fresh__assignment_status").select status }
    click_button 'Save changes'
  end

  def check_reassigned_shift_values rider, status
    expect(page.find("#row_1_col_3").text).to eq rider.name
    expect(page.find("#row_2_col_3").text).to eq rider.name
    expect(page.find("#row_3_col_3").text).to eq rider.name

    expect(page.find("#row_1_col_4").text).to eq status
    expect(page.find("#row_2_col_4").text).to eq status
    expect(page.find("#row_3_col_4").text).to eq status
  end

  def check_reassigned_shift_values_after_accepting_obstacle rider_1, rider_2, status
    expect(page.find("#row_1_col_3").text).to eq rider_2.name
    expect(page.find("#row_2_col_3").text).to eq rider_1.name
    expect(page.find("#row_3_col_3").text).to eq rider_1.name

    expect(page.find("#row_1_col_4").text).to eq status
    expect(page.find("#row_2_col_4").text).to eq status
    expect(page.find("#row_3_col_4").text).to eq status
  end

  def select_batch_assign_shifts_from_grid
    page.within("#row_1_col_6"){ find("#ids_").set true }
    page.within("#row_1_col_8"){ find("#ids_").set true }
    page.within("#row_1_col_10"){ find("#ids_").set true }   
  end

  def check_reassigned_shift_values_in_grid rider, status_code
    expect(page.find("#row_1_col_6").text).to eq "#{rider.short_name} #{status_code}"
    expect(page.find("#row_1_col_8").text).to eq "#{rider.short_name} #{status_code}"
    expect(page.find("#row_1_col_10").text).to eq "#{rider.short_name} #{status_code}"     
  end

  def load_batch
    let(:start_t){ Time.zone.local(2014,1,1,12) }
    let(:end_t){ Time.zone.local(2014,1,1,18) }
    let!(:batch)do
      3.times.map do |n|
        FactoryGirl.build(:shift, :with_restaurant, restaurant: restaurant, start: start_t + n.days, :end => end_t + n.days)
      end
    end
  end

  def load_conflicts
    let(:conflicts) do 
      3.times.map do |n| 
        FactoryGirl.build(:conflict, :with_rider, rider: other_rider, start: batch[n].start, :end => batch[n].end)
      end
    end
  end

  def load_double_bookings
    let(:double_bookings) do 
      3.times.map do |n|
        FactoryGirl.build(:shift, :with_restaurant, restaurant: restaurant, start: batch[n].start, :end => batch[n].end)
      end
    end
  end

  def load_free_rider
    let!(:free_rider){ FactoryGirl.create(:rider) }
  end
end


# ************************************************
#  RIDER MAILER SPEC MACROS
# app/spec/support/rider_mailer_macros.rb
# ************************************************

module RiderMailerMacros
  
  def load_staffers
    let(:tess){ FactoryGirl.create(:staffer, :tess) }
    let(:justin){ FactoryGirl.create(:staffer, :justin) }    
  end

  def load_delegation_scenario

    let!(:rider){ FactoryGirl.create(:rider) }
    let!(:restaurant){ FactoryGirl.create(:restaurant) }
    
    let(:now){ Time.zone.local(2014,1,6,11) }
    let(:start_t){ now + 1.hour }
    let(:end_t){ now + 7.hours }    

    # let(:start_t){ Time.zone.now.beginning_of_day + 12.hours }
    # let(:end_t){ Time.zone.now.beginning_of_day + 18.hours }

    let(:extra_shift){ FactoryGirl.create(:shift, :with_restaurant, restaurant: restaurant, start: start_t + 3.days, :end => end_t + 3.days) }
    let(:emergency_shift){ FactoryGirl.create(:shift, :with_restaurant, restaurant: restaurant, start: start_t + 1.day, :end => end_t + 1.day) }

    before do 
      rider.contact.update(name: 'A'*10)
      restaurant.mini_contact.update(name: 'A'*10)
    end    
  end

  def load_batch_delegation_scenario
    let!(:other_rider){ FactoryGirl.create(:rider) }
    let!(:other_restaurant){ FactoryGirl.create(:restaurant) }
    
    let(:extra_shifts) do 
      4.times.map do |n| 
        this_restaurant = is_even?(n) ? restaurant : other_restaurant #even shifts belong to restaurant, odd to other_restaurant
        FactoryGirl.create(:shift, :with_restaurant, restaurant: this_restaurant, start: start_t + (n+3).days, :end => end_t + (n+3).days)
      end
    end

    let(:emergency_shifts) do 
      4.times.map do |n| 
        m = n < 2 ? n*6 : (6*n+12)

        this_restaurant = is_even?(n) ? restaurant : other_restaurant #even shifts belong to restaurant, odd to other_restaurant
        FactoryGirl.create(:shift, :with_restaurant, restaurant: this_restaurant, start: start_t + m.hours, :end => end_t + m.hours ) 
        # FactoryGirl.create(:shift, :with_restaurant, restaurant: this_restaurant, start: start_t + ((n+2)/2).days + (n/2*6).hours, :end => end_t + ((n+2)/2).days + (n/2*6).hours)
      end
    end

    let(:mixed_batch) do
      4.times.map{ |n| n < 2 ? extra_shifts[n] : emergency_shifts[n]  }
    end

    # let(:mixed_shifts){ [ emergency_shift, extra_shift ] }
    # change to include 4 shifts so can be passed to batch delegate

    before do
      other_rider.contact.update(name: 'A'*9+'a')
      other_restaurant.mini_contact.update(name: 'A'*9+'a')
    end
  end

  def load_conflict_request_scenario
    let!(:riders){ 3.times.map{ FactoryGirl.create(:rider) } }
    let(:week_start){ Time.zone.local(2014,1,6) }
    let(:week_end){ Time.zone.local(2014,1,12) }
    let(:start_t){ week_start + 12.hours }
    let(:end_t){ week_start + 18.hours }
    let!(:conflicts) do
      arr_1 = 7.times.map do |n|
        if n!= 5
          start_ = start_t + n.days
          end_ = start_ + 6.hours
          FactoryGirl.create(:conflict, :with_rider, rider: riders[0], start: start_, :end => end_ )
        end
      end
      arr_2 = 7.times.map do |n|
        if n != 6
          start_ = end_t + n.days
          end_ = start_ + 6.hours
          FactoryGirl.create(:conflict, :with_rider, rider: riders[0], start: start_, :end => end_ )
        end
      end
      arr_1 + arr_2
    end
    let!(:mail_count){ ActionMailer::Base.deliveries.count }

  end # load_conflict_request_scenario

  def is_even? n
    (n+2)%2 == 0 
  end

  def load_schedule_email_scenario
    let(:restaurants){ 7.times.map{ |n| FactoryGirl.create(:restaurant) } }
    let(:schedule) do
      7.times.map { |n| FactoryGirl.create(:shift, :with_restaurant, restaurant: restaurants[n], start: start_t + 12.hours + (7+n).days, :end => start_t + 18.hours + (7+n).days) }
    end
  end

  # def load_delegation_email_scenario
  #   let(:mail){ RiderMailer.delegation_email rider, shift }
  # end

  def assign shift, status
    visit edit_shift_assignment_path(shift, shift.assignment)
    page.find("#assignment_rider_id").select rider.name
    page.find("#assignment_status").select status
    click_button 'Save changes'
  end


  def batch_delegate shifts, type
    visit shifts_path
    #set time filters inclusively
    select Time.zone.local(2013).year, from: 'filter_start_year'
    select Time.zone.local(2015).year, from: 'filter_end_year'
    #filter out all restaurants but test restaurants
    Restaurant.all.each { |r| unselect r.name, from: 'filter_restaurants' }
    select restaurant.name, from: "filter_restaurants"
    select other_restaurant.name, from: "filter_restaurants"
    click_button 'Filter' 
    # sort by restaurant
    click_link 'Restaurant'
    #select and submit test restaurants' shifts for batch assignment
    page.within("#row_1"){ find("#ids_").set true }
    page.within("#row_2"){ find("#ids_").set true }
    page.within("#row_3"){ find("#ids_").set true } 
    page.within("#row_4"){ find("#ids_").set true } 
      
    click_button 'Batch Assign', match: :first
    #assign shifts
    assign_extra if type == :extra
    assign_emergency if type == :emergency
    delegate_emergency if type == :emergency_delegation
    assign_mixed if type == :mixed 
    click_button 'Save changes'
  end

  def assign_extra
    #batch delegate shifts: first two shifts to rider, second two to other_rider
    4.times do |n|
      the_rider = n < 2 ? rider : other_rider

      page.within("#assignments_fresh_#{n}") do
        find("#wrapped_assignments_fresh__assignment_rider_id").select the_rider.name
        find("#wrapped_assignments_fresh__assignment_status").select 'Delegated'
      end
    end   
  end

  def assign_emergency
    # batch confirm shifts: 0 & 1 to rider, 2 & 3 to other_rider
    4.times do |n|
      the_rider = n < 2 ? rider : other_rider

      page.within("#assignments_fresh_#{n}") do
        find("#wrapped_assignments_fresh__assignment_rider_id").select the_rider.name
        find("#wrapped_assignments_fresh__assignment_status").select 'Confirmed'
      end
    end
  end

  def delegate_emergency
    # batch confirm shifts: 0 & 1 to rider, 2 & 3 to other_rider
    4.times do |n|
      the_rider = n < 2 ? rider : other_rider

      page.within("#assignments_fresh_#{n}") do
        find("#wrapped_assignments_fresh__assignment_rider_id").select the_rider.name
        find("#wrapped_assignments_fresh__assignment_status").select 'Delegated'
      end
    end
  end

  def assign_mixed
    # batch assign: 0 (confirmed), 1 (delegated) to rider ; 2 (confirmed), 3 (delegated) to other_rider
    4.times do |n|
      the_rider = is_even?(n) ? rider : other_rider
      status = n < 2 ? 'Confirmed' : 'Delegated'

      page.within("#assignments_fresh_#{n}") do
        find("#wrapped_assignments_fresh__assignment_rider_id").select the_rider.name
        find("#wrapped_assignments_fresh__assignment_status").select status
      end
    end
  end

  # SINGLE EMAIL MACROS

  def check_delegation_email_metadata mail, staffer, type
    expect(mail.to).to eq [ rider.email ]
    expect(mail.subject).to eq subject_from type
    expect(mail.from).to eq [ "brooklynshift@gmail.com" ]
  end

  def subject_from type
    case type
    when :extra
      '[EXTRA SHIFT] -- CONFIRMATION REQUIRED'
    when :emergency
      "[EMERGENCY SHIFT] -- SHIFT DETAILS ENCLOSED"
    end  
  end

  def check_delegation_email_body mail, staffer, type
    actual_body = parse_body_from mail
    expected_body = File.read("spec/mailers/sample_emails/single_#{staffer}_#{type}.html")

    expect(actual_body).to eq expected_body
  end

  # BATCH EMAIL MACROS

  def check_batch_delegation_email_metadata mails, type
    from = [ "brooklynshift@gmail.com" ]
    emails = [ rider.email, other_rider.email ]
    subject = batch_subject_from type

    mails.each_with_index do |mail, i|
      expect(mail.from).to eq from
      expect(mail.to).to eq [ emails[i] ]
      expect(mail.subject).to eq subject      
    end    
  end

  def check_mixed_batch_delegation_email_metadata mails
    from = [ "brooklynshift@gmail.com" ]
    emails = [ rider.email, rider.email, other_rider.email, other_rider.email ]
    subjects = [ subject_from(:emergency), subject_from(:extra), subject_from(:emergency), subject_from(:extra) ]
    
    mails.each_with_index do |mail, i|
      expect(mail.from).to eq from
      expect(mail.to).to eq [ emails[i] ]
      expect(mail.subject).to eq subjects[i]
      # puts ">>>> MAIL #{i} SUBJECT"
      # puts mail.subject
      # puts ">>>> MAIL #{i} TO"
      # puts mail.to
    end
  end

  def batch_subject_from type
    case type
    when :weekly
      "[WEEKLY SCHEDULE] -- PLEASE CONFIRM BY SUNDAY"
    when :extra
      '[EXTRA SHIFTS] -- CONFIRMATION REQUIRED'
    when :emergency
      "[EMERGENCY SHIFTS] -- SHIFT DETAILS ENCLOSED"
    end
  end

  def check_batch_delegation_email_body mails, staffer, type
    mails.each_with_index do |mail, i|
        # puts ">>>>>> MAIL #{i}"
        # print mail.body
      actual_body = parse_body_from mail
      expected_body = File.read( "spec/mailers/sample_emails/batch_#{staffer}_#{type}_#{i}.html" )

      expect(actual_body).to eq expected_body
    end
  end

  def check_conflict_request_email_bodies mails, riders
    mails.each_with_index do |mail, i|
        puts ">>>>>> MAIL #{i}"
        print mail.body
      actual_body = parse_body_from mail
      expected_body = expected_conflict_request_body_for riders[i], i

      expect(actual_body).to eq expected_body
    end
  end

  def check_conflict_request_metadata mails, riders
    from = [ "brooklynshift@gmail.com" ]
    subject = "[SCHEDULING CONFLICT REQUEST] 1/13 - 1/19"

    mails.each_with_index do |mail, i|
      expect(mail.from).to eq from
      expect(mail.to).to eq [ riders[i].email ]
      expect(mail.subject).to eq subject
    end
  end

  # HELPERS

  def parse_body_from mail
    mail.body.encoded.gsub("\r\n", "\n")
  end

  def expected_conflict_request_body_for rider, i
    str = File.read( "spec/mailers/sample_emails/conflicts_request_#{i}.html" )
    str.gsub('<RIDER_ID>', "#{rider.id}")
  end
  
end
