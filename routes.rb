# **********************
# ROUTES
# app/config/routes.rb
# **********************

BksOnRails::Application.routes.draw do

  # ...

  get 'shift/batch_edit' => 'shifts#batch_edit'
  post 'shift/batch_edit' => 'shifts#batch_update'

  get 'assignment/batch_edit' => 'assignments#batch_edit'
  post 'assignment/batch_edit' => 'assignments#batch_update'

  get 'assignment/batch_edit_uniform' => 'assignments#batch_edit_uniform'
  post 'assignment/batch_edit_uniform' => 'assignments#batch_update_uniform'

  get 'assignment/resolve_obstacles' => 'assignments#request_obstacle_decisions'
  post 'assignment/resolve_obstacles' => 'assignments#resolve_obstacles'
  post 'assignment/batch_reassign' => 'assignments#batch_reassign'

  # ...
end