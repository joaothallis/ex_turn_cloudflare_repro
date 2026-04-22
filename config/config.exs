import Config

config :logger, level: :info

# ExTURN.Client logs its "Failed to create allocation, reason: 437" line at
# :debug. Lower its module threshold and promote its events to :info so the
# signature is visible without flipping the whole app to :debug.
:logger.set_module_level(ExTURN.Client, :debug)

:logger.add_primary_filter(
  :ex_turn_debug_to_info,
  {fn
     %{level: :debug, meta: %{mfa: {ExTURN.Client, _, _}}} = event, _extra ->
       %{event | level: :info}

     _event, _extra ->
       :ignore
   end, nil}
)
