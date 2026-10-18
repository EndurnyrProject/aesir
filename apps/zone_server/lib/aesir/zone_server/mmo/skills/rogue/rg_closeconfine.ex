defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgCloseconfine do
  @moduledoc """
  Roots the target for 10 seconds and starts or extends its caster's hold for
  one extra second. Renewal grants the caster 50 FLEE and costs 40 SP; classic
  grants 10 FLEE and costs 25 SP. A refused recipient still completes the cast.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 1005,
    name: :rg_closeconfine,
    requires: [],
    display_name: "Close Confine",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 1,
    sp_cost: [renewal: [40], pre_renewal: [25]],
    duration: [10_000],
    quest_skill: true,
    quest_owner_job: :rogue

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_ref}, level, definition) do
    adapter = Caster.for(caster)
    caster_type = adapter.unit_type(caster)
    caster_id = adapter.id(caster)
    target_id = unit_id(target_ref)

    with {:ok, _pid, _target, target_type} <- TargetResolver.resolve(target_ref) do
      StatusInterpreter.apply_status(target_type, target_id, :sc_closeconfine2,
        val1: level,
        val2: caster_id,
        caster_id: caster_id,
        source_type: caster_type,
        duration: hd(definition.duration)
      )

      {:ok, caster}
    end
  end

  defp unit_id({_unit_type, unit_id}), do: unit_id
  defp unit_id(unit_id), do: unit_id
end
