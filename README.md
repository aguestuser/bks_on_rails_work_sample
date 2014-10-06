## WORK SAMPLE FROM BK SHIFT ON RAILS ##

This repo containts a cross-section from my web app, [BK Shift on Rails](https://github.com/aguestuser/bks_on_rails), containing the work from that project which required the most thinking, and of which I am the most proud. 

The code in this repo carries out a recursive loop for checking whether a rider to whom a staffer wants to assign a shift has scheduling conflicts and/or other shifts during that time. The program works by building an Assignments object that sorts potential assignments into arrays of assignments with conflicts, with double bookings, or without obstacles.  Assuming the former two arrays are not empty, the loop passes this object across a series of requests, maintaining and mutating the above three arrays, as it gives the user a chance to reassign shifts with scheduling obstacles or override those obstacles. Once all assignments have been moved into the array of assignments without obstacles, the loop will allow the user to save, then prompt them to correct any validation errors in the batch of assignments, then (assuming no errors) carry out a batch save and send riders an email containing a description of all the shifts that have been assigned to them. 

Execution of the loop crosses from view to controller to model several times, using a number of helper classes and parsing methods along the way. From beginning to end, the path of the loop's execution could be considered a mini-program in its own right, the core logic of which is decoupled from Rails, except where it makes use of built-in functions for convenience and (of course) when it writes to the database. For simplicity's sake, I've tried to condense snippets from the controllers, models, views, helpers, etc.. into one file for each category, which constitute the file structure of this repo.

Here are some parts I'd like to call your attention to:

* Shifts Controller
** This is where the call to assign a group of shifts is first made and (when it is determined that the user wants to edit a series of assignments and not the shifts themselves in line 30), passed along to the Assignments controller

* Assignments Helper Class
** This is the workhorse of the program. Initialized in AssignmentsController#batch_update/#batch_update_uniform, the object retains memory of the intial state of the assignments that will have edits saved to them at the end of execution (the @old array, which is cloned from the set of @fresh assignments passed into it at the top of execution), and builds a series of other arrays (@with_conflicts, @with_obstacles, and @with_double_bookings) that will be mutated incrementally with every call to AssignmentsController#get_savable. 
**(If I'd wanted to make this *truly* function, I would have returned a new instance of the Assignments object with every iteration, but I decided that mutating it in clearly documented ways and testing for discrete changes in state at every state would suffice for my purposes)
** It also contains several class methods to assist with retaining the original indexing of the array of assignments passsed into it at initialization (so that it can restore that indexing before saving) and for parsing and reconstituting the object as it is passed through several HTTP requests

* Assignments Controller
** Lines 55-85 get and parse user input about the assignments the user is seeking to make ("uniform batch assign" is simply a method for hanlding a use-case in which the user wants to assign all the shifts to the same rider), before calling the workhorse of the program get_savable(assignments)
** Get_savable(assignments) takes over on line 110, starting a recursive call to itself that will continue until all the assignments stored in the Assignments object that it takes as its only argument no longer have any scheduling conflicts
** If there are any assignments with obstacles (either conflicts or double bookings), get_savable will pass the assignments object to a view requesting decisions for each obstacle (called by request_obstacle_decisions on line 134). This view will gather decisions and POST them (along with the assignments object) to the resolve_obstacles method on line 89. This method will call the Assignments.resolve_obstacles_with(decisions) class method (line 53 in helpers.rb), which will sort @assignments_with_obstacles into assignments whose obstacle has been overriden (and thus resolved and a member of @without_obstacles), or designated for reassignment (and thus a member of @requiring_reassignment)
** At this point, get_savable is called again, and if any obstacles require reasignment remain in the Assignments object, it will pass them to the request_reassignments_for(assignments) private method, which will render a view that POSTS proposed reassignments (along with the rest of the Assignments object, still being retained in memory) to the batch_reassign method on line 98
** If all the new reassignments are conflict-free, get_savable continues to try to save them and then email them out (doing error handling and correcting along the way). If not, they will be passed to resolve_obstaces_with(decisions) and the whole process will start over again, until the user has chosen a set of assignments (and/or overrides) that remove all scheduing obstacles


* Views
** These are maybe not that important, but I put them in so you could see the way I used them to construct paramaters that would reconstruct the Assignments object across requests as the form in each view submits to a different controller action that takes a paramaterized version of the Assignments object as its only argument. While not strictly "continuation passing," the specification of a method and the passing of an argument to it within a POST request was closely enough related to that concept, that I learned a little bit about it to make this work, and that was hard, and I want to learn more about it, so there you go. :)

* Models
** Nothing too fancy going on here, but some of the basic logic of determining which assignments actually conflict with or double book with what happens here, so I included them so you could have a complete picture of how everything works. FWIW: I tried where possible to separate concerns and keep logic that was appropriate to a certain entity contained within the model representing that entity.

* Mailers
** These also aren't all that important, but they're what makes the whole thing actually do something in the world, and I made use of the RiderMailer helper class to abstract some of their logic into locally-understandable chunks (which I was proud of), so I figured I'd include it here

* Specs
** There are so many different permutations of how this program could work (or not). I tested darn near all of them!

