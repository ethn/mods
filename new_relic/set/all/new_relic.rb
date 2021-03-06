event :new_relic_act_transaction,
      after: :act do
  ::NewRelic::Agent.set_transaction_name "#{@action}-#{type_code}",
                                         category: :controller
  add_custom_card_attributes
  ::NewRelic::Agent.add_custom_attributes(
    act:  {
      time: "#{(Time.now - @act_start) * 1000} ms",
      actions: @current_act &&
               @current_act.actions.map(&:card).compact.map(&:name)
    }
  )
end

event :new_relic_read_transaction,
      before: :show_page, on: :read, when: :production? do
  ::NewRelic::Agent.set_transaction_name "read-#{type_code}",
                                         category: :controller
  add_custom_card_attributes
end

def production?
  Rails.env.production?
end

event :notify_new_relic, after: :notable_exception_raised do
  ::NewRelic::Agent.notice_error Card::Error.current
end

event :new_relic_act_start, before: :act do
  @act_start = Time.now
end

def add_custom_card_attributes
  ::NewRelic::Agent.add_custom_attributes(
    card: {
      type: type_code,
      name: name
    },
    user: {
      roles: all_roles.join(", ")
    }
  )
end

::Card::Set::Event::IntegrateWithDelayJob.after_perform do |job|
  card = job.arguments.first
  actions = card.current_act &&
            card.current_act.actions.map(&:card).compact.map(&:name)
  ::NewRelic::Agent.add_custom_attributes(
    event: job.queue_name,
    card: {
      name: card.name,
      type: card.type_code
    },
    act: { actions: actions },
  )
end

# test new relic custom metrics
# module ::ActiveRecord::ConnectionAdapters
#   class AbstractMysqlAdapter
#     unless method_defined? :new_relic_execute
#       alias_method :new_relic_execute, :execute
#       def execute sql, name=nil
#         result, duration = count_ms { original_execute(sql, name) }
#         ::NewRelic::Agent.record_metric "Custom/Card/queries", duration
#         result
#       end
#
#       def count_ms
#         start = Time.now
#         result = yield
#         [result, (Time.now - start) * 1000]
#       end
#     end
#   end
# end
