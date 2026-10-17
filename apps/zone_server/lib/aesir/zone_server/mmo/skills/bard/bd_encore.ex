defmodule Aesir.ZoneServer.Mmo.Skills.Bard.BdEncore do
  @moduledoc """
  Encore (BD_ENCORE) starts instantly without spending its own SP. Its skill
  request starts the remembered performance as a separate attempt, with its
  own cast time and half of its raw SP cost, needing an instrument or whip.

  Renewal adds a 0.3 s delay and a 10 s cooldown to Encore; pre-renewal has
  neither. The remembered cast keeps its own timing, cost and cooldown.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 305,
    name: :bd_encore,
    display_name: "Encore",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    range: 0,
    sp_cost: [1],
    cast_time: [0],
    fixed_cast_time: [0],
    after_cast_delay: [renewal: [300], pre_renewal: []],
    cooldown: [renewal: [10_000], pre_renewal: []],
    require_weapon: [:musical, :whip],
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost

  @behaviour Active

  @impl Active
  def validate(caster, :self, _level, _definition) do
    with {:ok, %{skill_id: skill_id}} <- replay_memory(caster),
         true <- Catalog.replayable?(skill_id),
         {:ok, remembered} <- Catalog.by_id(skill_id),
         :ok <- Caster.Player.knows?(caster, remembered, 1, :begin) do
      :ok
    else
      false -> {:error, :skill_not_replayable}
      :error -> {:error, :unknown_skill}
      error -> error
    end
  end

  @impl Active
  def dynamic_cost(_caster, :self, _level, _definition),
    do: %Cost{sp_requirement: 1, sp: 0}

  @impl Active
  def cast(caster, :self, _level, _definition), do: {:ok, caster}

  defp replay_memory(%{last_song: nil}), do: {:error, :no_song_to_replay}
  defp replay_memory(%{last_song: memory}) when is_map(memory), do: {:ok, memory}
end
