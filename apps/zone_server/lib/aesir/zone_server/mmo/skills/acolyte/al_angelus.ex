defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlAngelus do
  @moduledoc """
  Angelus (AL_ANGELUS). Applies SC_ANGELUS to the caster; when the caster is in
  a party, also splashes it (best-effort, the caster's own result is what the
  cast returns) to online party members on the same map within the splash
  radius. Every recipient gets the same magnitude (`5 * level`) and the same
  duration (thirty seconds per level, half a minute to five minutes).

  Renewal: a 350ms variable cast plus a fixed 150ms, a half-second after-cast
  delay, a thirty-second cooldown, and a party splash reaching eighteen cells.
  The buff itself raises soft defence off half the recipient's VIT and adds flat
  maximum HP.

  Pre-renewal: a flat 500ms cast with no fixed component, three and a half
  seconds of after-cast delay and no cooldown at all. The party splash covers
  the whole visible area rather than a tighter radius, and the buff raises soft
  defence as a percentage of the recipient's existing soft defence with no
  maximum-HP bonus. The declared pre-renewal radius is the server's visible-area
  size, which is what the source's "unbounded" splash marker resolves to.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 33,
    name: :al_angelus,
    status: :sc_angelus,
    display_name: "Angelus",
    max_level: 10,
    target_type: :self,
    damage_kind: :magic,
    splash_radius: [renewal: 18, pre_renewal: 14],
    sp_cost: [23, 26, 29, 32, 35, 38, 41, 44, 47, 50],
    cast_time: [renewal: List.duplicate(350, 10), pre_renewal: List.duplicate(500, 10)],
    fixed_cast_time: [renewal: List.duplicate(150, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(500, 10), pre_renewal: List.duplicate(3_500, 10)],
    cooldown: [renewal: List.duplicate(30_000, 10), pre_renewal: []],
    damage_splash: true

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Shared.PartySplash
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    params = [val1: level, val2: 5 * level, caster_id: caster_id, duration: 30_000 * level]

    case StatusInterpreter.apply_status(:player, caster_id, :sc_angelus, params) do
      :ok ->
        splash_to_party(caster, definition.splash_radius, params)
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  defp splash_to_party(caster, splash_radius, params) do
    caster
    |> PartySplash.nearby_member_ids(splash_radius)
    |> Enum.each(&StatusInterpreter.apply_status(:player, &1, :sc_angelus, params))
  end
end
