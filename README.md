## WORK SAMPLE FROM BK SHIFT ON RAILS ##

This repo containts a cross-section from my web app, [BK Shift on Rails](https://github.com/aguestuser/bks_on_rails), containing the work from that project which required the most thinking, and of which I am the most proud. 

The code in this repo carries out a recursive routine for checking whether a rider to whom a staffer wants to assign a shift has scheduling conflicts and/or other shifts during that time. The routine works by building an Assignments object that sorts potential assignments into lists of assignments with conflicts, with double bookings, or without obstacles.  Assuming the former two lists are not empty, the routine passes this object across a series of requests, maintaining and mutating a wrapper class that tracks the contents of all three lists, as it gives the user a chance to reassign shifts with scheduling obstacles or override those obstacles. 

Once all assignments have been moved into the list of assignments without obstacles, the routine will allow the user to save, then prompt them to correct any validation errors in the batch of assignments, then (assuming no errors) carry out a batch save and send riders an email containing a description of all the shifts that have been newly assigned to them (riders who had been previously assigned a shift will not receive an email). 

Execution of the routine crosses from view to controller to model several times, using a number of helper classes and parsing methods along the way. From beginning to end, the path of the loop's execution could be considered a mini-program in its own right, the core logic of which is nested within but in many respect independent from Rails (with obvious exceptoions where it uses rails DSL to access paramaters, write to the database, etc.). For simplicity's sake, I've tried to condense snippets from the controllers, models, views, helpers, etc.. into one file for each category, which constitute the file structure of this repo.

Here are some parts I'd like to call your attention to:

* [Shifts Controller](https://github.com/aguestuser/bks_on_rails_work_sample/blob/master/controllers.rb#L5-L47)
  * This is where the call to assign a group of shifts is first made and (when it is determined that the user wants to edit a series of assignments and not the shifts themselves in line 30), passed along to the Assignments controller

* [Assignments Helper Class](https://github.com/aguestuser/bks_on_rails_work_sample/blob/master/helpers.rb#L5-L157)
  * This is the workhorse of the program. Initialized in AssignmentsController#batch_update/#batch_update_uniform, the object retains memory of the intial state of the assignments that will have edits saved to them at the end of execution (the @old array, which is cloned from the set of @fresh assignments passed into it at the top of execution), and builds a series of other arrays (@with_conflicts, @with_obstacles, and @with_double_bookings) that will be mutated incrementally with every call to AssignmentsController#get_savable. 
  * (If I'd wanted to make this *truly* function, I would have returned a new instance of the Assignments object with every iteration, but I decided that mutating it in clearly documented ways and testing for discrete changes in state at every state would suffice for my purposes)
  * It also contains several class methods to assist with retaining the original indexing of the array of assignments passsed into it at initialization (so that it can restore that indexing before saving) and for parsing and reconstituting the object as it is passed through several HTTP requests

* [Assignments Controller](https://github.com/aguestuser/bks_on_rails_work_sample/blob/master/controllers.rb#L49-L233)
  * Lines 55-85 get and parse user input about the assignments the user is seeking to make ("uniform batch assign" is simply a method for hanlding a use-case in which the user wants to assign all the shifts to the same rider), before calling the workhorse of the program get_savable(assignments)
  * Get_savable(assignments) takes over on line 110, starting a recursive call to itself that will continue until all the assignments stored in the Assignments object that it takes as its only argument no longer have any scheduling conflicts
  * If there are any assignments with obstacles (either conflicts or double bookings), get_savable will pass the assignments object to a view requesting decisions for each obstacle (called by request_obstacle_decisions on line 134). This view will gather decisions and POST them (along with the assignments object) to the resolve_obstacles method on line 89. This method will call the Assignments.resolve_obstacles_with(decisions) class method (line 53 in helpers.rb), which will sort @assignments_with_obstacles into assignments whose obstacle has been overriden (and thus resolved and a member of @without_obstacles), or designated for reassignment (and thus a member of @requiring_reassignment)
  * At this point, get_savable is called again, and if any obstacles require reasignment remain in the Assignments object, it will pass them to the request_reassignments_for(assignments) private method, which will render a view that POSTS proposed reassignments (along with the rest of the Assignments object, still being retained in memory) to the batch_reassign method on line 98
  * If all the new reassignments are conflict-free, get_savable continues to try to save them and then email them out (doing error handling and correcting along the way). If not, they will be passed to resolve_obstaces_with(decisions) and the whole process will start over again, until the user has chosen a set of assignments (and/or overrides) that remove all scheduing obstacles


* [Views](https://github.com/aguestuser/bks_on_rails_work_sample/blob/master/views.html.haml)
  * These are maybe not that important, but I put them in so you could see the way I used them to construct paramaters that would allow the target form action for each view to reconstruct the Assignments object across several requests and at several different stages in the overal execution of the get_savable loop. While this is not strictly speaking an example of continuation passing (at least I don't think it is) the idea is similar, and learning about how CPS works was helpful in thinking how to design this aspect of the the routine's architecture. Continuation passing seems very interesting, and I want to learn more about it, so there you go. :)

* [Models](https://github.com/aguestuser/bks_on_rails_work_sample/blob/master/models.rb)
  * Nothing too fancy going on here, but some of the basic logic of determining which assignments actually conflict with or double book with what happens here, so I included them so you could have a complete picture of how everything works. FWIW: I tried where possible to separate concerns and keep logic that was appropriate to a certain entity contained within the model representing that entity.

* [Mailer](https://github.com/aguestuser/bks_on_rails_work_sample/blob/master/mailer.rb)
  * These also aren't all that important, but they're what makes the whole thing actually do something in the world, and I made use of the [RiderShifts](https://github.com/aguestuser/bks_on_rails_work_sample/blob/master/helpers.rb#L159-L276) and [DelegationEmailHelper](https://github.com/aguestuser/bks_on_rails_work_sample/blob/master/helpers.rb#L282-L351) helper classes to abstract some of their logic into locally-understandable chunks (which I was proud of), so I figured I'd include all that here

* [Specs](https://github.com/aguestuser/bks_on_rails_work_sample/blob/master/specs.rb)
  * There are so many different permutations of how this program could work (or not). I tested darn near all of them! (And built a bunch of helpful [macros](https://github.com/aguestuser/bks_on_rails_work_sample/blob/master/spec_macros.rb) along the way)

