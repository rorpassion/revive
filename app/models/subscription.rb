class Subscription < ActiveRecord::Base
  belongs_to :user
  belongs_to :plan

  attr_accessor :stripe_card_token
  attr_accessor :stripe_plan_id

  validates_presence_of :stripe_customer_token, :message => 'Stripe Error'

  def save_with_stripe!(stripe_plan = (stripe_plan_id.present? ? stripe_plan_id : false ) || plan_id )
    # It has dynamic stripe plan variable if it exists either set
    # through controller or already on user or passed on call
    # which allows us to use it as upgrade as well.

    valid_params = (user.email && stripe_plan_id.present? && stripe_card_token.present?)

    if valid_params

      # Create customer and Set Card
      customer = Stripe::Customer.create(email: user.email, plan: stripe_plan_id, card: stripe_card_token)
      # Save Plan, Status and Customer Token
      self.update({plan_id: stripe_plan_id, status: 'active', stripe_customer_token: customer.id})

    elsif stripe_customer_token.present?

      customer = Stripe::Customer.retrieve(stripe_customer_token)

      customer.subscriptions.create(plan: stripe_plan)

      plan = Plan.find_by_name(stripe_plan)

      self.update(plan_id: plan, status:'active')

      self.save!

    else

      return false

    end

  end

  def unsubscribe_with_stripe
    customer = Stripe::Customer.retrieve(stripe_customer_token)
    sub_id = customer.subscriptions.data.find{|sub| sub[:plan][:id] == plan_id.to_s}[:id]
    delete = customer.subscriptions.retrieve(sub_id).delete
    if delete[:status] == 'cancelled'
      self.update(status: 'cancelled')
    end

  end

  def active?
    case status
      when 'active'
        true
      when 'canceled' || 'cancelled'
        false
      else
        false
    end
  end
  
end
