defmodule Aesir.ZoneServer.Unit.Pet.Runtime do
  @moduledoc """
  Process-local bookkeeping for the pet owned by a player session.

  Not persisted and not published. Every pet timer carries `generation`; it is
  bumped whenever the pet leaves the world so stale timer events are dropped.
  """

  @typedoc "A scheduled OTP timer reference."
  @type timer_ref :: reference() | nil

  @typedoc "An in-progress capture: the lure used and its catch flag."
  @type catch_process :: %{lure_id: pos_integer(), flag: integer()}

  @enforce_keys []
  defstruct generation: 0,
            hunger_timer_ref: nil,
            ai_timer_ref: nil,
            movement_timer_ref: nil,
            movement_path: [],
            next_walk_at_ms: 0,
            move_fail_count: 0,
            can_move_at_ms: 0,
            can_act_at_ms: 0,
            catch_process: nil,
            autobonus_timers: %{},
            skill_bonus_timer_ref: nil,
            recovery_timer_ref: nil,
            support_skill_timer_ref: nil

  @type t() :: %__MODULE__{
          generation: non_neg_integer(),
          hunger_timer_ref: timer_ref(),
          ai_timer_ref: timer_ref(),
          movement_timer_ref: timer_ref(),
          movement_path: [{integer(), integer()}],
          next_walk_at_ms: integer(),
          move_fail_count: non_neg_integer(),
          can_move_at_ms: integer(),
          can_act_at_ms: integer(),
          catch_process: catch_process() | nil,
          autobonus_timers: %{optional(term()) => reference()},
          skill_bonus_timer_ref: timer_ref(),
          recovery_timer_ref: timer_ref(),
          support_skill_timer_ref: timer_ref()
        }
end
