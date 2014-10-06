# *******************
# ***** MODELS ******
# *******************

# ************************
# SHIFT MODEL
# app/models/shift.rb
# ************************

# == Schema Information
#
# Table name: shifts
#
#  id            :integer          not null, primary key
#  restaurant_id :integer
#  start         :datetime
#  end           :datetime
#  period        :string(255)
#  urgency       :string(255)
#  billing_rate  :string(255)
#  notes         :text
#  created_at    :datetime
#  updated_at    :datetime
#

class Shift < ActiveRecord::Base
  include Timeboxable, BatchUpdatable

  belongs_to :restaurant
  has_one :assignment, dependent: :destroy #inverse_of: :shift
    accepts_nested_attributes_for :assignment

  classy_enum_attr :billing_rate
  classy_enum_attr :urgency

  validates :restaurant_id, :billing_rate, :urgency,
    presence: true

  def build_associations
    self.assignment = Assignment.new
  end

  def rider
    self.assignment.rider
  end

  def assigned? #output: bool
    !self.assignment.rider.nil?
  end

  def assign_to(rider, status=:proposed) 
    #input: Rider, AssignmentStatus(Symbol) 
    #output: self.Assignment
    params = { rider_id: rider.id, status: status } 
    if self.assigned?
      self.assignment.update params
    else
      self.assignment = Assignment.create! params
    end
  end

  def unassign
    self.assignment.update(rider_id: nil, status: :unassigned) if self.assigned?
  end

  def conflicts_with? conflict
    ( conflict.end >= self.end && conflict.start < self.end ) || 
    ( conflict.start <= self.start && conflict.end > self.start )
    # ie: if the conflict under examination overlaps with this conflict 
  end

  def double_books_with? shift
    ( shift.end >= self.end && shift.start <  self.end ) || 
    ( shift.start <= self.start && shift.end > self.start )
    # ie: if the shift under examination overlaps with this shift
  end

  def refresh_urgency now
    #input self (implicit), DateTime Obj
    #side-effects: updates shift's urgency attribute
    #output: self 
      
    start = self.start
    send_urgency( parse_urgency( now, start ) ) if start > now 
    self
  end

  private

    def parse_urgency now, start
      #input: Datetime, Datetime
      #output: Symbol
      next_week = start.beginning_of_week != now.beginning_of_week
      time_gap = start - now
      
      if next_week
        :weekly
      elsif time_gap <= 36.hours
        :emergency
      else
        :extra
      end
    end

    def send_urgency urgency
      #input: Symbol
      self.update(urgency: urgency)
    end  

end

# ************************
# RIDER MODEL
# app/models/rider.rb
# ************************

# == Schema Information
#
# Table name: riders
#
#  id         :integer          not null, primary key
#  active     :boolean
#  created_at :datetime
#  updated_at :datetime
#

class Rider < ActiveRecord::Base
  include User, Contactable, Equipable, Locatable # app/models/concerns/

  #nested attributes
  has_one :qualification_set, dependent: :destroy
    accepts_nested_attributes_for :qualification_set
  has_one  :skill_set, dependent: :destroy
    accepts_nested_attributes_for :skill_set
  has_one :rider_rating, dependent: :destroy
    accepts_nested_attributes_for :rider_rating
  
  #associations
  has_many :assignments
  has_many :shifts, through: :assignments
  has_many :conflicts 

  validates :active, inclusion: { in: [ true, false ] }

  scope :testy, -> { joins(:contact).where("contacts.email = ?", "bkshifttester@gmail.com").first }
  scope :active, -> { joins(:contact).where(active: true).order("contacts.name asc") }
  scope :inactive, -> { joins(:contact).where(active: false).order("contacts.name asc") }
  
#public methods
  def name
    self.contact.name
  end

  def shifts_on(date) #input: date obj, #output Arr of Assignments (possibly empty)
    self.shifts.where( start: (date.beginning_of_day..date.end_of_day) )
  end

  def conflicts_on(date) #input: date obj, #output Arr of Conflicts (possibly empty)
    self.conflicts.where( start: (date.beginning_of_day..date.end_of_day) )
  end

  def conflicts_between start_t, end_t
    #input: Rider(self/implicit), Datetiem, Datetime
    #does: builds an array of conflicts belonging to rider within date range btw/ start_t and end_t
    #output: Arr
    conflicts = self.conflicts
      .where( "start > :start AND start < :end", { start: start_t, :end => end_t } )
      .order("start asc")
  end

  #class methods
  def Rider.select_options
    Rider.all.joins(:contact).order("contacts.name asc").map{ |r| [ r.name, r.id ] }
  end

  def Rider.email_conflict_requests rider_conflicts, week_start, account
    #input: RiderConflicts, Datetime, Account
    #output: Str (empty if no emails sent, email alert if emails sent)
    count = 0
    rider_conflicts.arr.each do |hash| 
      RiderMailer.request_conflicts(hash[:rider], hash[:conflicts], week_start, account).deliver
      count += 1
    end
    
    alert = count > 0 ? "#{count} conflict requests successfully sent" : ""
  end
end

# ************************
# ASSIGNMENT MODEL
# app/models/rider.rb
# ************************

# == Schema Information
#
# Table name: assignments
#
#  id                      :integer          not null, primary key
#  shift_id                :integer
#  rider_id                :integer
#  status                  :string(255)
#  created_at              :datetime
#  updated_at              :datetime
#  override_conflict       :boolean
#  override_double_booking :boolean
#

class Assignment < ActiveRecord::Base
  include BatchUpdatable
  belongs_to :shift #, inverse_of: :assignment
  belongs_to :rider

  classy_enum_attr :status, allow_nil: true, enum: 'AssignmentStatus'

  before_validation :set_status, if: :status_nil?

  validates :status, presence: true
  validate :no_emergency_shift_delegation

  #instance methods

  def no_emergency_shift_delegation
    if self.shift
      if self.shift.urgency == :emergency
        errors.add(:base, 'Emergency shifts cannot be delegated') unless self.status != :delegated
      end
    end
  end

  def conflicts
    #input: self (implicit)
    #output: Arr of Conflicts
    if self.rider.nil?
      []
    else
      rider_conflicts = get_rider_conflicts 
      rider_conflicts.select { |conflict| self.shift.conflicts_with? conflict }
    end
  end

  def double_bookings 
    rider_shifts = get_rider_shifts
    if self.rider.nil?
      []
    else 
      rider_shifts.select { |shift| self.shift.double_books_with? shift }
    end
  end

  def resolve_obstacle
    self.conflicts.each(&:destroy) if self.conflicts.any?
    self
  end

  def save_success_message
    self.rider.nil? ? "Assignment updated (currently unassigned)." : "Assignment updated (Rider: #{self.rider.contact.name}, Status: #{self.status.text})"
  end


  def try_send_email old_assignment, sender_account
    if self.status == :delegated && ( old_assignment.status != :delegated || old_assignment.rider != self.rider )
      send_email_from sender_account
      true
    else 
      false
    end 
  end

  #Class Methods

  def Assignment.send_emails new_assignments, old_assignments, sender_account
    #input: assignments <Arr of Assignments>, old_assignments <Arr of Assignments>, Account
    #does: 
      # (1) constructs array of newly delegated shifts
      # (2) parses list of shifts into sublists for each rider
      # (3) parses list of shifts for restaurants
      # (4) [ SIDE EFFECT ] sends batch shift delegation email to each rider using params built through (1), (2), and (3)
    #output: Int (count of emails sent)
    # delegations = Assignment.delegations_from new_assignments, old_assignments # (1)
    # rider_shifts = RiderShifts.new(delegations).hash #(2), (3)
    
    emailable_shifts = Assignment.emailable new_assignments, old_assignments
    rider_shifts = RiderShifts.new(emailable_shifts).hash #(2), (3)
    
    count = 0
    rider_shifts.values.each do |rider_hash| # (4)
      [:emergency, :extra, :weekly].each do |urgency|
        if rider_hash[urgency][:shifts].any?
          Assignment.send_email rider_hash, urgency, sender_account
          count += 1
        end
      end
    end
    count
  end

  def Assignment.send_email rider_hash, urgency, sender_account
    RiderMailer.delegation_email( 
      rider_hash[:rider], 
      rider_hash[urgency][:shifts], 
      rider_hash[urgency][:restaurants],
      sender_account,
      urgency
    ).deliver
  end

  def Assignment.delegations_from new_assignments, old_assignments
    #input: Arr of Assignments, Arr of Assignments
    #does: builds array of assignments that were newly delegated when being updated from second argument to first
    #output: Arr of Assignments
    new_assignments.select.with_index do |a, i|  
      a.status == :delegated && ( old_assignments[i].status != :delegated || old_assignments[i].rider != a.rider )
    end
  end

  def Assignment.emailable new_assignments, old_assignments
    #input: Arr of Assignments, Arr of Assignments
    #does: builds array of assignments that were newly delegated when being updated from second argument to first
    #output: Arr of Assignments
    # raise ( "NEW ASSIGNMENTS: " + new_assignments.inspect + "OLD ASSIGNMENTS: " + old_assignments.inspect )
    new_assignments.select.with_index do |a, i| 
      if a.status == :delegated
        old_assignments[i].status != :delegated || old_assignments[i].rider != a.rider
      elsif a.status == :confirmed
        # raise ( old_assignments[i].rider != a.rider ).inspect
        val = ( a.shift.urgency == :emergency && ( old_assignments[i].status != :confirmed || old_assignments[i].rider != a.rider ) )
        # raise val.inspect
      else
        false
      end 
      # a.status == :delegated && ( old_assignments[i].status != :delegated || old_assignments[i].rider != a.rider ) ||
      # a.status == :confirmed && ( old_assignments[i].status != :confirmed || old_assignments[i].rider != a.rider )
    end
  end
  

  private

    #instance method helpers

    def status_nil?
      self.status.nil?
    end

    def set_status
      self.status = :unassigned
    end

    def get_rider_conflicts
      self.rider.conflicts_on self.shift.start
    end

    def get_rider_shifts
      if self.rider
        self.rider.shifts_on(self.shift.start).reject{ |s| s.id == self.shift.id }
      else
        []
      end
    end

    def send_email_from sender_account
      RiderMailer.delegation_email(self.rider, [ self.shift ], [ self.shift.restaurant ], sender_account).deliver
    end

end