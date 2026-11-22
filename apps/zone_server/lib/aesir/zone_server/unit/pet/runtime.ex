defmodule Aesir.ZoneServer.Unit.Pet.Runtime do
  @moduledoc """
  Process-local bookkeeping for the pet owned by a player session.

  `movement_path` is the whole walk and `path_pos` the steps taken on it;
  `walk_target` is a destination requested while
  walking, taken on the next cell; `chase_owner` marks a walk toward the owner;
  `teleport_timer_ref` is the 3 s owner recall.
  The `*_at_ms` deadlines are monotonic milliseconds, `nil` when none is set
  (the monotonic clock is negative on the BEAM, so 0 is not "no deadline").

  Not persisted and not published. Every pet timer carries `generation`; it is
  bumped whenever the pet leaves the world so stale timer events are dropped.
  """

  use TypedStruct

  @typedoc "A scheduled OTP timer reference."
  @type timer_ref :: reference() | nil

  @typedoc "An in-progress capture: the lure used and its catch flag."
  @type catch_process :: %{lure_id: pos_integer(), flag: integer()}

  @typedoc "Timer, movement and capture bookkeeping for one pet."
  typedstruct do
    field :generation, non_neg_integer(), default: 0
    field :hunger_timer_ref, timer_ref(), default: nil
    field :ai_timer_ref, timer_ref(), default: nil
    field :movement_timer_ref, timer_ref(), default: nil
    field :movement_path, [{integer(), integer()}], default: []
    field :path_pos, non_neg_integer(), default: 0
    field :walk_target, {integer(), integer()} | nil, default: nil
    field :chase_owner, boolean(), default: false
    field :teleport_timer_ref, timer_ref(), default: nil
    field :next_walk_at_ms, integer() | nil, default: nil
    field :move_fail_count, non_neg_integer(), default: 0
    field :can_move_at_ms, integer() | nil, default: nil
    field :can_act_at_ms, integer() | nil, default: nil
    field :catch_process, catch_process() | nil, default: nil
    field :autobonus_timers, %{optional(term()) => reference()}, default: %{}
    field :skill_bonus_timer_ref, timer_ref(), default: nil
    field :recovery_timer_ref, timer_ref(), default: nil
    field :support_skill_timer_ref, timer_ref(), default: nil
  end
end
