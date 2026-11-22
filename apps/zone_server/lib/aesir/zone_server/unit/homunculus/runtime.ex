defmodule Aesir.ZoneServer.Unit.Homunculus.Runtime do
  @moduledoc """
  Process-local bookkeeping for a Homunculus owned by a player session.

  This state is not persisted or published as a world snapshot.
  """

  use TypedStruct

  @typedoc "A scheduled OTP timer reference."
  @type timer_ref :: reference() | nil

  @typedoc "Timer, movement and regeneration bookkeeping for one homunculus."
  typedstruct do
    field :active_expiry_timer_ref, timer_ref(), default: nil
    field :active_deadline_ms, integer() | nil, default: nil
    field :clocks_online, boolean(), default: false
    field :hunger_timer_ref, timer_ref(), default: nil
    field :ai_timer_ref, timer_ref(), default: nil
    field :cast_timer_ref, timer_ref(), default: nil
    field :bio_explosion_timer_ref, timer_ref(), default: nil
    field :bio_explosion_descriptor, map() | nil, default: nil
    field :movement_timer_ref, timer_ref(), default: nil
    field :checkpoint_timer_ref, timer_ref(), default: nil
    field :separation_timer_ref, timer_ref(), default: nil
    field :cooldown_timer_ref, timer_ref(), default: nil
    field :movement_path, [{integer(), integer()}], default: []
    field :movement_step, {integer(), non_neg_integer()} | nil, default: nil
    field :movement_redirect, {integer(), integer()} | nil, default: nil
    field :last_basic_attack_at_ms, integer() | nil, default: nil
    field :hp_regen_deadline_ms, integer() | nil, default: nil
    field :sp_regen_deadline_ms, integer() | nil, default: nil
    field :private_dirty, boolean(), default: false, enforce: true
  end

  @doc "Returns every timer-reference field of this struct."
  @spec timer_fields() :: [atom()]
  def timer_fields do
    %__MODULE__{private_dirty: false}
    |> Map.from_struct()
    |> Map.keys()
    |> Enum.filter(&(&1 |> Atom.to_string() |> String.ends_with?("_timer_ref")))
  end
end
