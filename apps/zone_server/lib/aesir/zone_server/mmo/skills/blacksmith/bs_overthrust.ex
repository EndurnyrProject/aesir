defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsOverthrust do
  @moduledoc """
  Power-Thrust (BS_OVERTHRUST). Raises physical attack for the caster and every
  same-map party member holding a weapon within the default 14-cell area, for 20 s
  per level and 18 down to 10 SP; a Hilt Binding caster adds 10% duration.

  The caster always gets 5% per level. Renewal recipients get 5% at levels 1 and 2,
  10% at 3 and 4, and 15% at 5; pre-renewal recipients get a flat 5%. Pre-renewal
  also gives the caster's own attacks a 0.1% chance of breaking the weapon, which
  Aesir does not model in either mode.
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
    status: :sc_overthrust,
    require_weapon: [
      :book,
      :bow,
      :dagger,
      :gatling,
      :grenade,
      :huuma,
      :katar,
      :knuckle,
      :mace,
      :musical,
      :one_handed_axe,
      :one_handed_spear,
      :one_handed_sword,
      :revolver,
      :rifle,
      :shotgun,
      :staff,
      :two_handed_axe,
      :two_handed_mace,
      :two_handed_spear,
      :two_handed_staff,
      :two_handed_sword,
      :whip
    ]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.PartyBuff
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    duration = PartyBuff.duration_for_caster(caster, Enum.at(definition.duration, level - 1))

    recipient_params = [
      val1: recipient_rate(level),
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
             definition.splash_radius,
             &eligible_weapon?(&1, definition.require_weapon)
           ),
         :ok <- StatusInterpreter.apply_status(:player, caster_id, :sc_overthrust, caster_params) do
      {:ok, caster}
    end
  end

  # Party recipients get 5, 10, or 15% by level band in renewal and a flat 5% in classic.
  defp recipient_rate(level) do
    case GameMode.mode() do
      :renewal -> div(level + 1, 2) * 5
      :pre_renewal -> 5
    end
  end

  defp eligible_weapon?(%PlayerState{stats: %{equipment: equipment}}, accepted_weapons),
    do: Stats.weapon_type(equipment) in accepted_weapons

  defp eligible_weapon?(_player, _accepted_weapons), do: false
end
