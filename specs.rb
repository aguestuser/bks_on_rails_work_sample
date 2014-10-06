# ***************************
# ********** SPECS **********
# ***************************

# ************************************************
#  BATCH ASSIGNMENT SPECS
# app/spec/requests/shift_pages_spec.rb
# ************************************************


require 'spec_helper'
include CustomMatchers, RequestSpecMacros, ShiftRequestMacros, GridRequestMacros

describe "Shift Requests" do
  let!(:restaurant) { FactoryGirl.create(:restaurant) }
  let!(:other_restaurant) { FactoryGirl.create(:restaurant) }
  let!(:rider){ FactoryGirl.create(:rider) }
  let!(:other_rider){ FactoryGirl.create(:rider) }
  let(:shift) { FactoryGirl.build(:shift, :with_restaurant, restaurant: restaurant) }
  let(:shifts) { 31.times.map { FactoryGirl.create(:shift, :without_restaurant) } }
  let(:staffer) { FactoryGirl.create(:staffer) }
  before { mock_sign_in staffer }

  subject { page }

  # ...

  describe "BATCH REQUESTS" do
    before { restaurant }
    
    let!(:old_count){ Shift.count }
    load_batch

    # ...

    describe "BATCH ASSIGN" do
      before do
        # initialize rider & shifts, assign shifts to rider
        other_rider
        batch.each(&:save)
        batch.each { |s| s.assignment.update(rider_id: rider.id, status: :confirmed) }
      end

      describe "from SHIFTS INDEX" do
        before do
          # select shifts for batch assignment
          visit shifts_path
          filter_shifts_by_time_inclusively
          page.within("#row_1"){ find("#ids_").set true }
          page.within("#row_2"){ find("#ids_").set true }
          page.within("#row_3"){ find("#ids_").set true }        
        end

        describe "with STANDARD batch edit" do
          before { click_button 'Batch Assign', match: :first }
          
          describe "batch edit assignment page" do 
            it "should have correct URI" do 
              check_batch_assign_uri
            end
            
            it { should have_h1 'Batch Assign Shifts' }
            it { should have_content(restaurant.name) }

            it "should have correct select values" do
              check_batch_assign_select_values rider, 'Confirmed'
            end
          end

          describe "EXECUTING batch assignment" do

            describe "WITHOUT OBSTACLES" do
              before { assign_batch_to other_rider, 'Proposed' }

              describe "after editing" do
                
                it "should redirect to the correct page" do
                  expect(current_path).to eq "/shifts/"
                end

                describe "index page" do
                  before { filter_shifts_by_time_inclusively }

                  it "should show new values of edited shifts" do
                    check_reassigned_shift_values other_rider, 'Proposed'
                  end
                end            
              end # "after editing"              
            end # "WITHOUT OBSTACLES"  

            describe "WITH CONFLICT" do
              load_conflicts
              before do
                conflicts[0].save
                assign_batch_to other_rider, 'Proposed'
              end
                
              describe "Resolve Obstacles page" do

                describe "CONTENTS" do
                  
                  it "should be the Resolve Obstacles page" do
                    expect(current_path).to eq "/assignment/batch_edit"
                    expect(page).to have_h1 'Resolve Scheduling Obstacles'
                  end

                  it "should correctly list Assignments With Conflicts" do
                    check_assignments_with_conflicts_list [0], [0]
                  end

                  it "should not list Assignments With Double Bookings" do
                    expect(page).not_to have_selector("#assignments_with_double_bookings")
                  end

                  it "should correctly list Assignments Without Obstacles" do
                    check_without_obstacles_list [0,1], [1,2]
                  end
                end # "CONTENTS"

                describe "OVERRIDING" do
                  before do
                    choose "decisions_0_Override"
                    click_button 'Submit'
                  end

                  describe "after submission" do
                    before { filter_shifts_by_time_inclusively }

                    it "should redirect to the index page" do
                      expect(current_path).to eq "/shifts/"
                      expect(page).to have_h1 'Shifts'
                    end

                    it "should show new values for reassigned shifts" do
                      check_reassigned_shift_values other_rider, 'Proposed'
                    end
                  end # "after submission (on shifts index)"
                end # "OVERRIDING"

                describe "ACCEPTING" do
                  load_free_rider
                  before do
                    choose 'decisions_0_Accept'
                    click_button 'Submit'
                  end

                  describe "after submission" do

                    describe "batch reassign page" do

                      it "should be the batch reassign page" do
                        expect(current_path).to eq '/assignment/resolve_obstacles'
                        expect(page).to have_h1 'Batch Reassign Shifts'                         
                      end

                      it "should correctly list Assignements Requiring Reassignment" do
                        check_reassign_single_shift_list other_rider, 'Proposed', 0
                      end

                      it "should not list Assignments With Double Bookings" do
                        expect(page).not_to have_selector("#assignments_with_double_bookings")
                      end

                      it "should correctly list Assignments Without Obstacles" do
                        check_without_obstacles_list [0,1], [1,2]
                      end                        
                    end

                    describe "executing REASSIGNMENT TO FREE RIDER" do
                      before { reassign_single_shift_to free_rider, 'Proposed' }

                      describe "after submission" do
                        
                        it "should redirect to the correct page" do
                          expect(current_path).to eq "/shifts/"
                          expect(page).to have_h1 'Shifts'
                        end

                        describe "index page" do
                          before { filter_shifts_by_time_inclusively }

                          it "shoud show new values for reassigned shifts" do
                            check_reassigned_shift_values_after_accepting_obstacle other_rider, free_rider, 'Proposed'
                          end
                        end #"index page"
                      end # "after submission"
                    end # "executing REASSIGNMENT TO FREE RIDER"

                    describe "executing REASSIGNMENT TO RIDER WITH CONFLICT" do
                      before{ click_button 'Save changes' }

                      it "should redirect to resolve obstacles page" do
                        expect(current_path).to eq "/assignment/batch_reassign"
                        expect(page).to have_h1 'Resolve Scheduling Obstacles'
                      end
                    end #"executing REASSIGNMENT TO RIDER WITH CONFLICT"

                    describe "executing REASSIGNMENT TO RIDER WITH DOUBLE BOOKING" do
                      load_double_bookings
                      before do
                        double_bookings[0].save
                        double_bookings[0].assign_to free_rider
                        reassign_single_shift_to free_rider, 'Confirmed'
                      end

                      it "should redirect to resolve obstacles page" do
                        expect(current_path).to eq "/assignment/batch_reassign"
                        expect(page).to have_h1 'Resolve Scheduling Obstacles'
                      end
                    end #"executing REASSIGNMENT TO RIDER WITH CONFLICT"
                  end # "after submission"
                end # "ACCEPTING"
              end # "Resove Obstacles Page"

            end # "WITH CONFLICT"

            describe "WITH 2 CONFLICTS" do
              load_conflicts
              before do
                conflicts[0..1].each(&:save)
                assign_batch_to other_rider, 'Proposed'
              end

              describe "Resolve Obstacles page" do

                describe "CONTENTS" do
                  
                  it "should be the Resolve Obstacles page" do
                    expect(current_path).to eq "/assignment/batch_edit"
                    expect(page).to have_h1 'Resolve Scheduling Obstacles'
                  end

                  it "should correctly list Assignments With Conflicts" do
                    check_assignments_with_conflicts_list [0,1], [0,1]
                  end

                  it "should not list Assignments With Double Bookings" do
                    expect(page).not_to have_selector("#assignments_with_double_bookings")
                  end

                  it "should correctly list Assignments Without Obstacles" do
                    check_without_obstacles_list [0], [2]
                  end
                end # "CONTENTS"
              end # "Resolve Obstacles page"
            end # "WITH 2 CONFLICTS"

            describe "WITH 3 CONFLICTS" do
              load_conflicts
              before do
                conflicts.each(&:save)
                assign_batch_to other_rider, 'Proposed'
              end

              describe "Resolve Obstacles page" do

                describe "CONTENTS" do
                  
                  it "should be the Resolve Obstacles page" do
                    expect(current_path).to eq "/assignment/batch_edit"
                    expect(page).to have_h1 'Resolve Scheduling Obstacles'
                  end

                  it "should correctly list Assignments With Conflicts" do
                    check_assignments_with_conflicts_list [0,1,2], [0,1,2]
                  end

                  it "should not list Assignments With Double Bookings" do
                    expect(page).not_to have_selector("#assignments_with_double_bookings")
                  end

                  it "should not list Assignments Without Obstacles" do
                    expect(page).not_to have_selector("#assignments_without_obstacles")
                  end
                end # "CONTENTS"
              end # "Resolve Obstacles page"
            end # "WITH 3 CONFLICTS"

            describe "WITH DOUBLE BOOKING" do
              load_double_bookings
              before do
                double_bookings[0].save
                double_bookings[0].assign_to other_rider
                assign_batch_to other_rider, 'Proposed'
              end

              describe "Resolve Obstacles page" do
                
                describe "CONTENTS" do
                  
                  it "should be the Resolve Obstacles page" do
                    expect(current_path).to eq "/assignment/batch_edit"
                    expect(page).to have_h1 'Resolve Scheduling Obstacles'
                  end

                  it "should not list Assignments With Conflicts" do
                    expect(page).not_to have_selector("#assignments_with_conflicts")
                  end

                  it "should correctly list Assignments With Double Bookings" do
                    check_assignments_with_double_booking_list [0], [0]
                  end

                  it "should correctly list Assignments Without Obstacles" do
                    check_without_obstacles_list [0,1], [1,2]
                  end
                end # "CONTENTS"

                describe "OVERRIDING" do
                  before do
                    choose "decisions_0_Override"
                    click_button 'Submit'
                  end

                  describe "after submission" do
                    
                    it "should redirect to the correct page" do
                      expect(current_path).to eq "/shifts/"
                      expect(page).to have_h1 'Shifts'
                    end

                    describe "index page" do
                      before { filter_shifts_by_time_inclusively }

                      it "shoud show new values for reassigned shifts" do
                        check_reassigned_shift_values other_rider, 'Proposed'
                      end
                    end # "index page"
                  end # "after submission"
                end # "OVERRIDING"

                describe "ACCEPTING" do
                  load_free_rider
                  before do
                    choose 'decisions_0_Accept'
                    click_button 'Submit'
                  end

                  describe "after submission" do

                    describe "batch reassign page" do

                      it "should redirect to the correct page" do
                        expect(current_path).to eq '/assignment/resolve_obstacles'
                        expect(page).to have_h1 'Batch Reassign Shifts'                         
                      end

                      it "should correctly list Assignements Requiring Reassignment" do
                        check_reassign_single_shift_list other_rider, 'Proposed', 0
                      end

                      it "should not list Assignments With Double Bookings" do
                        expect(page).not_to have_selector("#assignments_with_double_bookings")
                      end

                      it "should correctly list Assignemnts Without Obstacles" do
                        check_without_obstacles_list [0,1], [1,2]
                      end                        
                    end

                    describe "executing REASSIGNMENT TO FREE RIDER" do
                      before { reassign_single_shift_to free_rider, 'Proposed' }

                      describe "after submission" do
                        
                        it "should redirect to the correct page" do
                          expect(current_path).to eq "/shifts/"
                          expect(page).to have_h1 'Shifts'
                        end

                        describe "index page" do
                          before { filter_shifts_by_time_inclusively }

                          it "shoud show new values for reassigned shifts" do
                            check_reassigned_shift_values_after_accepting_obstacle other_rider, free_rider, 'Proposed'
                          end
                        end #"index page"
                      end # "after submission"
                    end # "executing REASSIGNMENT TO FREE RIDER"
                  end # "after submission"
                end # "ACCEPTING"
              end # "Resolve Obstacles page"
            end # "WITH DOUBLE BOOKING"

            describe "WITH 2 DOUBLE BOOKINGS" do
              load_double_bookings
              before do
                double_bookings[0..1].each do |shift|
                  shift.save
                  shift.assign_to other_rider
                end
                assign_batch_to other_rider, 'Proposed'
              end

              describe "Resolve Obstacles page" do

                describe "CONTENTS" do
                  
                  it "should be the Resolve Obstacles page" do
                    expect(current_path).to eq "/assignment/batch_edit"
                    expect(page).to have_h1 'Resolve Scheduling Obstacles'
                  end

                  it "should not list Assignments With Conflicts" do
                    expect(page).not_to have_selector("#assignments_with_conflicts")
                  end

                  it "should correctly list Assignments With Double Bookings" do
                    check_assignments_with_double_booking_list [0,1], [0,1]
                  end

                  it "should correctly list Assignments Without Obstacles" do
                    check_without_obstacles_list [0], [2]
                  end
                end # "CONTENTS"
              end # "Resolve Obstacles page"
            end # "WITH 2 DOUBLE BOOKINGS"

            describe "WITH 3 DOUBLE BOOKINGS" do
              load_double_bookings
              before do
                double_bookings.each do |shift|
                  shift.save
                  shift.assign_to other_rider
                end
                assign_batch_to other_rider, 'Proposed'
              end

              describe "Resolve Obstacles page" do

                describe "CONTENTS" do
                  
                  it "should be the Resolve Obstacles page" do
                    expect(current_path).to eq "/assignment/batch_edit"
                    expect(page).to have_h1 'Resolve Scheduling Obstacles'
                  end

                  it "should not list Assignments With Conflicts" do
                    expect(page).not_to have_selector("#assignments_with_conflicts")
                  end

                  it "should correctly list Assignments With Double Bookings" do
                    check_assignments_with_double_booking_list [0,1,2], [0,1,2]
                  end

                  it "should not list Assignments Without Obstacles" do
                    expect(page).not_to have_selector("#assignments_without_obstacles")
                  end
                end # "CONTENTS"
              end # "Resolve Obstacles page"
            end # "WITH 2 DOUBLE BOOKINGS"

            describe "WITH CONFLICT AND DOUBLE BOOKING" do
              load_conflicts
              load_double_bookings
              before do
                conflicts[0].save
                double_bookings[1].save
                double_bookings[1].assign_to other_rider
                assign_batch_to other_rider, 'Proposed'
              end

              describe "Resolve Obstacles Page" do
                
                describe "CONTENTS" do

                  it "should be the Resolve Obstacles page" do
                    expect(current_path).to eq "/assignment/batch_edit"
                    expect(page).to have_h1 'Resolve Scheduling Obstacles'
                  end

                  it "should correctly list Assignments With Conflicts" do
                    check_assignments_with_conflicts_list [0], [0]
                  end

                  it "should correctly list Assignments With Double Bookings" do
                    check_assignments_with_double_booking_list [0], [1]
                  end

                  it "should correctly list Assignments Without Obstacles" do
                    check_without_obstacles_list [0], [2]
                  end
                end # "CONTENTS"

                describe "OVERRIDING BOTH" do
                  before do
                    choose "decisions_0_Override"
                    choose "decisions_1_Override"
                    click_button 'Submit'                    
                  end

                  describe "after submission" do
                    before { filter_shifts_by_time_inclusively }

                    it "should redirect to the index page" do
                      expect(current_path).to eq "/shifts/"
                      expect(page).to have_h1 'Shifts'
                    end

                    it "should show new values for reassigned shifts" do
                      check_reassigned_shift_values other_rider, 'Proposed'
                    end
                  end # "after submission (on shifts index)"
                end # "OVERRIDING BOTH"

                describe "OVERRIDING CONFLICT / ACCEPTING DOUBLE BOOKING" do
                  before do
                    choose "decisions_0_Override"
                    choose "decisions_1_Accept"
                    click_button 'Submit' 
                  end

                  describe "after submission" do
                    
                    describe "batch reassign page" do

                      it "should be the batch reassign page" do
                        expect(current_path).to eq '/assignment/resolve_obstacles'
                        expect(page).to have_h1 'Batch Reassign Shifts'                         
                      end

                      it "should correctly list Assignments Requiring Reassignment" do
                        check_reassign_single_shift_list other_rider, 'Proposed', 1
                      end

                      it "should correctly list Assignments Without Obstacles" do
                        check_without_obstacles_list [0,1], [2,0]
                      end                        
                    end
                  end # "after submission"
                end # "OVERRIDING CONFLICT / ACCEPTING DOUBLE BOOKING"

                describe "ACCEPTING CONFLICT / OVERRIDING DOUBLE BOOKING" do
                  before do
                    choose "decisions_0_Accept"
                    choose "decisions_1_Override"
                    click_button 'Submit' 
                  end

                  describe "after submission" do
                    
                    describe "batch reassign page" do

                      it "should be the batch reassign page" do
                        expect(current_path).to eq '/assignment/resolve_obstacles'
                        expect(page).to have_h1 'Batch Reassign Shifts'                         
                      end

                      it "should correctly list Assignments Requiring Reassignment" do
                        check_reassign_single_shift_list other_rider, 'Proposed', 0
                      end

                      it "should correctly list Assignments Without Obstacles" do
                        check_without_obstacles_list [0,1], [2,1]
                      end                        
                    end # "batch reassign page"
                  end # "after submission"
                end # "OVERRIDING CONFLICT / ACCEPTING DOUBLE BOOKING"
              end # "Resolve Obstacles Page"
            end # "WITH CONFLICT AND DOUBLE BOOKING"
          end # "EXECUTING batch assignment"
        end # "with STANDARD batch edit"

        describe "with UNIFORM batch edit" do
          before { click_button 'Uniform Assign', match: :first }

          describe "Uniform Assign Shifts page" do
            
            it "should have correct URI and Header" do
              check_uniform_assign_uri
              expect(page).to have_h1 "Uniform Assign Shifts"
            end

            it "should list Shifts correctly" do
              check_uniform_assign_shift_list rider, 'Confirmed'
            end

            it "should have correct form values" do
              check_uniform_assign_select_values
            end
          end

          describe "EXECUTING batch assignment" do

            describe "WITHOUT OBSTACLES" do
              before { uniform_assign_batch_to other_rider, 'Cancelled (Rider)' }

              describe "after editing" do

                it "should redirect to the correct page" do
                  expect(current_path).to eq "/shifts/"
                  expect(page).to have_h1 'Shifts'
                end

                describe "index page" do
                  before { filter_shifts_by_time_inclusively }

                  it "should show new values for re-assigned shifts" do
                    check_reassigned_shift_values other_rider, 'Cancelled (Rider)'
                  end
                end # "index page"
              end # "after editing"               
            end # "WITHOUT OBSTACLES"

            describe "WITH CONFLICT" do
              load_conflicts
              before do
                conflicts[0].save
                uniform_assign_batch_to other_rider, 'Proposed'
              end
                                  
              it "should redirect to the Resolve Obstacles page" do
                expect(current_path).to eq "/assignment/batch_edit_uniform"
                expect(page).to have_h1 'Resolve Scheduling Obstacles'
              end
            end # "WITH CONFLICT"

            describe "WITH DOUBLE BOOKING" do
              load_double_bookings
              before do
                double_bookings[0].save
                double_bookings[0].assign_to other_rider
                uniform_assign_batch_to other_rider, 'Proposed'
              end
                  
              it "should be the Resolve Obstacles page" do
                expect(current_path).to eq "/assignment/batch_edit_uniform"
                expect(page).to have_h1 'Resolve Scheduling Obstacles'
              end
            end # "WITH DOUBLE BOOKING"
          end # "EXECUTING batch assignment"
        end # "Uniform Assign Shifts page"
      end # "with UNIFORM batch edit"

      describe "from GRID" do
        before do 
          restaurant.mini_contact.update(name: 'A'*10)
          visit shift_grid_path 
          filter_grid_for_jan_2014
        end

        describe "page contents" do

          describe "batch edit form" do

            it { should have_button 'Batch Assign' }
            it "should have correct form action" do
              expect(page.find("form.batch")['action']).to eq '/shift/batch_edit'
            end              
          end

          describe "grid rows" do

            it "should have correct cells in first row" do
              expect(page.find("#row_1_col_1").text).to eq 'A'*10
              expect(page.find("#row_1_col_6").text).to eq rider.short_name + " [c]"
              expect(page.find("#row_1_col_8").text).to eq rider.short_name + " [c]"
              expect(page.find("#row_1_col_10").text).to eq rider.short_name + " [c]"
            end              
          end
        end

        describe "STANDARD batch assignment" do
          before do
            select_batch_assign_shifts_from_grid
            click_button 'Batch Assign'
          end

          describe "batch assign page" do
            it "should have correct URI" do
              check_batch_assign_uri
            end

            it "should have correct assignment values" do
              check_batch_assign_select_values rider, 'Confirmed'
            end            
          end

          describe "executing batch assignment" do
            before { assign_batch_to rider, 'Proposed' }

            describe "after editing" do

              it "should redirect to the correct page" do
                expect(current_path).to eq "/grid/shifts"
              end

              describe "page contents" do
                before { filter_grid_for_jan_2014 }

                it "should have new assignment values" do
                  check_reassigned_shift_values_in_grid other_rider, '[p]'
                end
              end
            end
          end
        end

        describe "UNIFORM batch assignment" do
          before do 
            select_batch_assign_shifts_from_grid
            click_button 'Uniform Assign'
          end

          describe "uniform assign page" do
            
            it "should have correct uri" do
              check_uniform_assign_uri
            end

            it { should have_h1 'Uniform Assign Shifts' }
            it { should have_content restaurant.name }

            it "should have correct form values" do
              check_uniform_assign_select_values
            end
          end

          describe "executing batch edit" do
            before { uniform_assign_batch_to other_rider, 'Cancelled (Rider)' }

            describe "after editing" do
              it "should redirect to the correct page" do
                expect(current_path).to eq "/grid/shifts"
              end

              describe "index page" do
                before { filter_grid_for_jan_2014 }

                it "should show new values for re-assigned shifts" do
                  check_reassigned_shift_values_in_grid other_rider, '[xf]'
                end
              end
            end
          end
        end
      end 
    end  
  end
end


# ************************************************
#  RIDER MAILER SPECS
# app/spec/mailers/rider_mailer_spec.rb
# ************************************************

require 'spec_helper'
include RequestSpecMacros, RiderMailerMacros

describe "Rider Mailer Requests" do
  load_staffers

  describe "DELEGATION EMAIL" do
    load_delegation_scenario

    describe "as Tess" do
      before { mock_sign_in tess }

      describe "for extra shift" do
        let!(:mail_count){ ActionMailer::Base.deliveries.count }
        before { assign extra_shift, 'Delegated' }
        let(:mail){ ActionMailer::Base.deliveries.last }
      
        it "should send an email" do
          expect(ActionMailer::Base.deliveries.count).to eq (mail_count + 1)
        end
        
        it "should render correct email metadata" do
          check_delegation_email_metadata mail, :tess, :extra
        end
        
        it "should render correct email body" do
          check_delegation_email_body mail, :tess, :extra
        end
      end

      describe "for emergency shift" do
        let!(:mail_count){ ActionMailer::Base.deliveries.count }
        before { assign emergency_shift, 'Confirmed' }
        let(:mail){ ActionMailer::Base.deliveries.last }

        it "should send an email" do
          expect(ActionMailer::Base.deliveries.count).to eq (mail_count + 1)
        end
        
        it "should render correct email metadata" do
          check_delegation_email_metadata mail, :tess, :emergency
        end
        
        it "should render correct email body" do
          check_delegation_email_body mail, :tess, :emergency
        end
      end

      describe "trying to delegate an emergency shift" do
        before { assign emergency_shift, 'Delegated' }

        it "should redirect to error-handling page" do
          expect(page).to have_h1 'Batch Assign Shifts'  
        end

        it "should list shifts with errors correctly" do
          expect(page.within("#assignments_fresh_0"){ find(".field_with_errors").text }).to include(rider.name)
        end
      end # "trying to delegate an emergency shift"
    end # "as Tess"

    describe "as Justin" do
      before { mock_sign_in justin }

      describe "for extra shift" do
        let!(:mail_count){ ActionMailer::Base.deliveries.count }
        before { assign extra_shift, 'Delegated' }
        let(:mail){ ActionMailer::Base.deliveries.last }
        
        it "should send an email" do
          expect(ActionMailer::Base.deliveries.count).to eq (mail_count + 1)
        end
        
        it "should render correct email metadata" do
          check_delegation_email_metadata mail, :justin, :extra
        end
        
        it "should render correct email body" do
          check_delegation_email_body mail, :justin, :extra
        end
      end
    end #"as Justin"
  end # "ASSIGNMENT EMAIL"

  describe "BATCH DELEGATION EMAILS" do
    load_delegation_scenario
    load_batch_delegation_scenario

    describe "as Tess" do
      before { mock_sign_in tess }

      describe "for EXTRA shifts" do
        let!(:mail_count){ ActionMailer::Base.deliveries.count } 
        before { batch_delegate extra_shifts, :extra }
        let(:mails){ ActionMailer::Base.deliveries.last(2) }

        it "should send 2 emails" do
          expect( ActionMailer::Base.deliveries.count ).to eq mail_count + 2
        end

        it "should format email metadata correctly" do
          check_batch_delegation_email_metadata mails, :extra
        end

        it "should format email body correctly" do
          check_batch_delegation_email_body mails, :tess, :extra
        end
      end # "for EXTRA shifts"

      describe "for EMERGENCY shifts" do
        let!(:mail_count){ ActionMailer::Base.deliveries.count } 
        before { batch_delegate emergency_shifts, :emergency }
        let(:mails){ ActionMailer::Base.deliveries.last(2) }

        it "should send 2 emails" do
          expect( ActionMailer::Base.deliveries.count ).to eq mail_count + 2
        end

        it "should format email metadata correctly" do
          check_batch_delegation_email_metadata mails, :emergency
        end

        it "should format email body correctly" do
          check_batch_delegation_email_body mails, :tess, :emergency
        end
      end # "for EMERGENCY shifts"

      describe "for MIXED BATCH of shifts" do
        let!(:mail_count){ ActionMailer::Base.deliveries.count } 
        before { batch_delegate mixed_batch, :mixed }
        let(:mails){ ActionMailer::Base.deliveries.last(4) }

        it "should send 4 emails" do
          expect( ActionMailer::Base.deliveries.count ).to eq mail_count + 4
        end

        it "should format email metadata correctly" do
          check_mixed_batch_delegation_email_metadata mails
        end

        it "should format email body correctly" do
          check_batch_delegation_email_body mails, :tess, :mixed
        end
      end # "for "for MIXED BATCH of shifts"

      describe "trying to DELEGATE EMERGENCY shifts" do
        before { batch_delegate emergency_shifts, :emergency_delegation }

        it "should redirect to error-handling page" do
          expect(page).to have_h1 'Batch Assign Shifts'  
        end

        it "should list shifts with errors correctly" do
          expect(page.within("#assignments_fresh_0"){ find(".field_with_errors").text }).to include(rider.name)
          expect(page.within("#assignments_fresh_1"){ find(".field_with_errors").text }).to include(rider.name)
          expect(page.within("#assignments_fresh_2"){ find(".field_with_errors").text }).to include(rider.name)
          expect(page.within("#assignments_fresh_3"){ find(".field_with_errors").text }).to include(rider.name)
        end
      end # "trying to DELEGATE EMERGENCY shifts"
    end # "as Tess"
  end # "BATCH ASSIGNMENT EMAILS"

  # ....
end



