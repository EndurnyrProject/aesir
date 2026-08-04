defmodule Aesir.ZoneServer.Unit.Homunculus.Runtime do
  @moduledoc """
  Process-local bookkeeping for a Homunculus owned by a player session.

  This state is not persisted or published as a world snapshot.
  """

  @typedoc "A scheduled OTP timer reference."
  @type timer_ref :: reference() | nil

  @enforce_keys [:private_dirty]
  defstruct active_expiry_timer_ref: nil,
            active_deadline_ms: nil,
            clocks_online: false,
            hunger_timer_ref: nil,
            ai_timer_ref: nil,
            cast_timer_ref: nil,
            bio_explosion_timer_ref: nil,
            bio_explosion_descriptor: nil,
            movement_timer_ref: nil,
            checkpoint_timer_ref: nil,
            separation_timer_ref: nil,
            cooldown_timer_ref: nil,
            movement_path: [],
            last_basic_attack_at_ms: nil,
            hp_regen_deadline_ms: nil,
            sp_regen_deadline_ms: nil,
            private_dirty: false

  @type t() :: %__MODULE__{
          active_expiry_timer_ref: timer_ref(),
          active_deadline_ms: integer() | nil,
          clocks_online: boolean(),
          hunger_timer_ref: timer_ref(),
          ai_timer_ref: timer_ref(),
          cast_timer_ref: timer_ref(),
          bio_explosion_timer_ref: timer_ref(),
          bio_explosion_descriptor: map() | nil,
          movement_timer_ref: timer_ref(),
          checkpoint_timer_ref: timer_ref(),
          separation_timer_ref: timer_ref(),
          cooldown_timer_ref: timer_ref(),
          movement_path: [{integer(), integer()}],
          last_basic_attack_at_ms: integer() | nil,
          hp_regen_deadline_ms: integer() | nil,
          sp_regen_deadline_ms: integer() | nil,
          private_dirty: boolean()
        }

  @doc "Returns every timer-reference field of this struct."
  @spec timer_fields() :: [atom()]
  def timer_fields do
    %__MODULE__{private_dirty: false}
    |> Map.from_struct()
    |> Map.keys()
    |> Enum.filter(&(&1 |> Atom.to_string() |> String.ends_with?("_timer_ref")))
  end
end
