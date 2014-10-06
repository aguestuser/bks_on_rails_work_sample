# **************************
# RIDER MAILER
# app/mailers/rider_mailer.rb


class RiderMailer < ActionMailer::Base
  default from: "brooklynshift@gmail.com"
  helper_method :protect_against_forgery?
  
  def delegation_email rider, shifts, restaurants, account, type
    require 'delegation_email_helper'

    @rider = rider
    @shifts = shifts
    @restaurants = restaurants
    @staffer = account.user #, staffer_from account

    helper = DelegationEmailHelper.new shifts, type

    @salutation = "Dear #{rider.first_name}:"
    @offering = helper.offering
    @confirmation_request = helper.confirmation_request
    
    mail(to: rider.email, subject: helper.subject)
  end

  # ...

  private

    def protect_against_forgery?
      false
    end
      
end
