defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsOverthrust do
  @moduledoc """
  Over Thrust (BS_OVERTHRUST) increases physical attack for the caster and
  nearby party members, with the caster receiving a larger bonus at higher levels.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 113,
    name: :bs_overthrust,
    display_name: "Power-Thrust",
    max_level: 5,
    target_type: :self,
    splash_radius: 14,
    sp_cost: [18, 16, 14, 12, 10],
    duration: [20_000, 40_000, 60_000, 80_000, 100_000],
    status: :sc_overthrust

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.PartyBuff
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    duration = Enum.at(definition.duration, level - 1)

    recipient_params = [
      val1: div(level + 1, 2) * 5,
      caster_id: caster_id,
      duration: duration
    ]

    caster_params = Keyword.put(recipient_params, :val1, level * 5)

    # The party walk necessarily applies the party rate to the caster too, so the
    # caster's own stronger rate is applied second and overwrites it. Storage
    # replaces an existing entry of the same status on a newer generation, so the
    # second apply always wins; do not collapse these two calls into one. The
    # caster receives a duplicate status-icon broadcast as a result, which is
    # cosmetic and client-idempotent.
    with :ok <-
           PartyBuff.apply(
             caster,
             :sc_overthrust,
             recipient_params,
             definition.splash_radius
           ),
         :ok <- StatusInterpreter.apply_status(:player, caster_id, :sc_overthrust, caster_params) do
      {:ok, caster}
    end
  end
end
