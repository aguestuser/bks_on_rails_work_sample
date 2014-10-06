# *******************************
# ***** CONTROLLER HELPERS ******
# *******************************

# *********************
# ASSIGNMENTS CLASS
# app/helpers/assignments.rb
# ***************************

class Assignments
  include Hashable
  attr_accessor :fresh, :old, :with_conflicts, :with_double_bookings, :with_obstacles, :without_obstacles, :requiring_reassignment

  def initialize options={}
    @old = options[:old] || options[:fresh].clone # Array of WrappedAssignments 
    # NOTE: above will clone fresh options on first iteration, retain initial value of @old on subsequent (recursive) iterations
    @fresh = options[:fresh] || [] # Array of WrapedAssignments

    @with_conflicts =  options[:with_conflicts] || [] # Arr of WrapedAssignments
    @with_double_bookings =  options[:with_double_bookings] || [] # Arr of WrapedAssignments
    @without_obstacles = options[:without_obstacles] || [] # Arr of WrapedAssignments
    @requiring_reassignment = options[:requiring_reassignment] || [] #Arr of WrapedAssignments
  end

  def with_obstacles
    @with_conflicts + @with_double_bookings 
  end

  def find_obstacles
    #input: @fresh (implicit - must be loaded) Arr of Assignments
    #does: 
      # sorts assignments from fresh into 3 Arrays: 
        # (1) @with_conflicts: Arr of Assignments with conflicts
        # (2) @with_double_bookings: Arr of Assignmens with double bookings
        # (3) @without_obstacles: Arr of Assignments with neither conflicts nor double bookings 
      # clears @fresh
    # output: Assignments Obj

    @fresh.each do |wrapped_assignment|
      assignment = wrapped_assignment.assignment
      if assignment.conflicts.any?
        @with_conflicts.push wrapped_assignment
      elsif assignment.double_bookings.any?
        @with_double_bookings.push wrapped_assignment
      else
        @without_obstacles.push wrapped_assignment
      end
    end
    @fresh = []
    self
  end

  def resolve_obstacles_with decisions
    #input: @with_conflicts (implicit) Array of Assignments, @with_double_bookings (implicit) Array of Assignments
    #does: 
      # builds array of assignments with obstacles
      # based on user decisions, sorts them into either 
        # (1) assignments @requiring_reassignment
        # (2) assignments @without_obstacles (after clearing obstacles from assignment object)
      # clears @with_conflicts, @with_double_bookings, returns new state of Assignments Object
    with_obstacles = self.with_obstacles

    with_obstacles.each_with_index do |wrapped_assignment, i|
      case decisions[i]
      when 'Accept' # move to @requiring_reassignment
        self.requiring_reassignment.push wrapped_assignment 
      when 'Override' # resolve obstacle and move to @without_obstacles
        wrapped_assignment.assignment.resolve_obstacle
        self.without_obstacles.push wrapped_assignment
      end      
    end 
    self.with_conflicts = []
    self.with_double_bookings = []
    self
  end

  def savable
    #input: self (implicit) Assignments Obj, @without_obstacles (implicit) Array of WrappedAssignments
    #does: restores Arr of WrappedAssignments without obstacles to original sort and returns unwrapped Arr of Assignments
    #output: Array of Assignments
    savable = @without_obstacles.sort_by{ |wrapped_assignment| wrapped_assignment.index }
    savable.map(&:assignment)
  end

  def unwrap_old
    #input: self (implicit), @old (implicit) Array of WrappedAssignments
    #output: Array of Assignments
    @old.map(&:assignment)
  end

  # def to_params
  #   self.to_json.to_query 'assignments'
  # end

  # CLASS METHODS

  def Assignments.wrap assignments
    assignments.each_with_index.map { |assignment, i| WrappedAssignment.new(assignment, i) }
  end

  def Assignments.wrap_with_indexes assignments, indexes
    assignments.each_with_index.map { |assignment, i| WrappedAssignment.new(assignment, indexes[i]) } 
  end

  def Assignments.from_params param_hash
    #input Hash of type
      # { 'fresh': [
      #     {
      #       id: Num,
      #       assignment:{
      #         'id': Num,
      #         'rider_id': Num,
      #         'shift_id': Num,
      #         ...(other Assignment attributes)
      #       }
      #     }     
      #    'id': Num
      #    ],
      #   'old': [
      #     {
      #       'id': Num,
      #       'assignment':{
      #         ...(Assignment attributes)...
      #       }
      #     }
      #   ].... (other Arrays of WrappedAssignment attributes)   
      # }
    #does: parses params hash into WrappedAssignments that can be passed as options to initialize an Assignments object
    #output: Assignments Obj

    options = {}
    param_hash.each do |key, wrapped_attr_arr|
      index_arr = wrapped_attr_arr.map{ |wrapped_attrs| wrapped_attrs['index'] }
      attr_arr = wrapped_attr_arr.map{ |wrapped_attrs| wrapped_attrs['assignment'] }
      assignments = attr_arr.map{ |attrs| Assignment.new(attrs) }

      options[key.to_sym] = Assignments.wrap_with_indexes assignments, index_arr
    end
    Assignments.new(options)
  end

  def Assignments.decisions_from params
    #input params[:decisions] (must be present)
    decisions = []
    params.each { |k,v| decisions[k.to_i] = v }
    decisions
  end

  class WrappedAssignment
    attr_accessor :assignment, :index

    def initialize assignment, index
      @assignment = assignment
      @index = index
    end
  end
end

# ******************************************
# RIDER-SHIFTS CLASS
# app/helpers/rider_shifts.rb
# ************************************************

class RiderShifts
  attr_reader :hash
  URGENCIES = [ :emergency, :extra, :weekly ]

  def initialize assignments
    @hash = hash_from assignments
    # puts ">>>> @hash"
    # pp @hash
  end

  private

    def hash_from assignments
      #input: Arr of assignments
            #output: Hash of Hashes of type:
        # { Num<rider_id>: 
          # { rider: Rider, 
            # emergency_ shifts: {
              # shifts: Arr of Shifts, 
              # restaurants: Arr of Restaurants
            # }
            # extra_shifts: {
              # shifts: Arr of Shifts 
              # restaurants: Arr of Restaurants
            # } 
        # }
      grouped_by_rider = group_by_rider assignments
      with_parsed_rider_and_shift = parse_rider_and_shifts grouped_by_rider
      grouped_by_urgency = group_by_urgency with_parsed_rider_and_shift
      with_restaurants = insert_restaurants grouped_by_urgency
      # sorted_by_date = sort_by_date grouped_by_urgency
      # with_restaurants = insert_restaurants sorted_by_date
    end

    def group_by_rider assignments
      #input: Array of type: [ Assignment, Assignment, ...]
      #output: Hash of type: { Num(rider_id): Arr of Assignments }
      assignments.group_by{ |a| a.rider.id }
    end

    def parse_rider_and_shifts assignments
      #input: Hash of type: { Num(rider_id): Arr of Assignments }
      #output: Hash of Hashes of type: { Num<rider_id>: { rider: Rider, shifts: Arr of Shifts } }
      hash = {}
      assignments.each do |id,assignments|
        hash[id] = { rider: assignments.first.rider, shifts: assignments.map(&:shift) }
      end
      hash
    end

    def group_by_urgency assignments
      #input: Hash of Hashes of type: { Num<rider_id>: { rider: Rider, shifts: Arr of Shifts } }
      #output: Hash of Hashes of type: 
        # { Num<rider_id>: 
          # { rider: Rider, emergency: Arr of Shifts, extra: Arr of Shifts, weekly: Arr of Shifts } 
        # }
      hash = {}
      assignments.each do |id, rider_hash|
        sorted_hash = rider_hash[:shifts].group_by{ |s| s.urgency.text.downcase.to_sym }
        hash[id] = { rider: rider_hash[:rider] }
        URGENCIES.each { |urgency| hash[id][urgency] = sorted_hash[urgency] }
      end
      hash
    end

    def sort_by_date assignments
      hash = {}
      assignments.each do |id, rider_hash|
        URGENCIES.each do |urgency|
          rider_hash[urgency].sort_by!{ |shift| shift.start } if rider_hash[urgency]
        end
      end
      hash
    end

    def insert_restaurants assignments
      #input: Hash of Hashes of type: 
        # { Num<rider_id>: 
          # { rider: Rider, emergency: Arr of Shifts, extra: Arr of Shifts } 
        # }
      #output: Hash of Hashes of type:
        # { Num<rider_id>: 
          # { rider: Rider, 
            # emergency_ shifts: {
              # shifts: Arr of Shifts, 
              # restaurants: Arr of Restaurants
            # }
            # extra_shifts: {
              # shifts: Arr of Shifts 
              # restaurants: Arr of Restaurants
            # } 
        # }
      hash = {}
      assignments.each do |id, rider_hash|
        hash[id] = { rider: rider_hash[:rider] }
        URGENCIES.each do |urgency|
          shifts = rider_hash[urgency] || []
          restaurants = parse_restaurants shifts
          hash[id][urgency] = urgency_hash_from shifts, restaurants
        end
      end
      hash
    end

    def urgency_hash_from shifts, restaurants
      { shifts: shifts , restaurants: restaurants }
    end

    def parse_restaurants shifts
      shifts.map{ |shift| shift.restaurant }.uniq
    end

end

# *******************************
# ******** MAILER HELPERS *******
# *******************************

# ******************************************
# DELEGATION EMAIL HELPER
# app/helpers/delegation_email_helper.rb
# ******************************************

class DelegationEmailHelper
  attr_accessor :subject, :offering, :confirmation_request

  def initialize shifts, type 

    plural = shifts.count > 1
    adj = type.to_s
    noun = noun_from type, plural

    @subject = subject_from adj, noun, shifts, type
    @offering = offering_from adj, noun, type
    @confirmation_request = conf_req_from noun, type

  end

  private

    def noun_from type, plural
      str = type == :weekly ? "schedule" : "shift"
      str << "s" if plural && type != :weekly
      str
    end

    def subject_from adj, noun, shifts, type
      "[" << adj.upcase << " " << noun.upcase << "] " << shift_descr_from(shifts, type)
    end

    def shift_descr_from shifts, type
      case type
      when :weekly
        "-- PLEASE CONFIRM BY SUNDAY"
      when :extra
        '-- CONFIRMATION REQUIRED'
      when :emergency
        "-- SHIFT DETAILS ENCLOSED"
      end
    end

    def offering_from adj, noun, type
      offer_prefix = offer_prefix_from type
      "#{offer_prefix} #{adj} #{noun}:"
    end

    def offer_prefix_from type
      if type == :emergency
        "As per our conversation, you are confirmed for the following"
      else 
        "We'd like to offer you the following"
      end
    end

    def conf_req_from noun, type
      if type == :emergency
        "Have a great shift!"
      else 
        conf_time = conf_time_from type
        "Please confirm whether you can work the #{noun} by #{conf_time}"
      end
    end

    def conf_time_from type
      type == :weekly ? "12pm this Sunday" : "2pm tomorrow"
    end

end
