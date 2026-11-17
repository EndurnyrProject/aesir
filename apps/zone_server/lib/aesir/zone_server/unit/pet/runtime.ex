defmodule Aesir.ZoneServer.Unit.Pet.Runtime do
  @moduledoc """
  Process-local bookkeeping for the pet owned by a player session.

  `movement_path` is the whole walk and `path_pos` the steps taken on it, as
  the reference's `walkpath`; `walk_target` is a destination requested while
  walking, taken on the next cell; `chase_owner` marks a walk toward the owner
  (`ud.target_to == master`); `teleport_timer_ref` is the 3 s owner recall.
  The `*_at_ms` deadlines are monotonic milliseconds, `nil` when none is set
  (the monotonic clock is negative on the BEAM, so 0 is not "no deadline").

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
            path_pos: 0,
            walk_target: nil,
            chase_owner: false,
            teleport_timer_ref: nil,
            next_walk_at_ms: nil,
            move_fail_count: 0,
            can_move_at_ms: nil,
            can_act_at_ms: nil,
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
          path_pos: non_neg_integer(),
          walk_target: {integer(), integer()} | nil,
          chase_owner: boolean(),
          teleport_timer_ref: timer_ref(),
          next_walk_at_ms: integer() | nil,
          move_fail_count: non_neg_integer(),
          can_move_at_ms: integer() | nil,
          can_act_at_ms: integer() | nil,
          catch_process: catch_process() | nil,
          autobonus_timers: %{optional(term()) => reference()},
          skill_bonus_timer_ref: timer_ref(),
          recovery_timer_ref: timer_ref(),
          support_skill_timer_ref: timer_ref()
        }
end
