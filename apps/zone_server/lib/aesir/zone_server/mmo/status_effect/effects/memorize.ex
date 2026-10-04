defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Memorize do
  @moduledoc """
  Foresight (SC_MEMORIZE). Halves the variable cast time of the holder's casts
  of skills they have learned, for five casts. A charge is spent at the start
  of every such cast, instant ones included and even when the cast time is not
  reduced; the fifth ends the status. Item-granted and automatic casts never
  start a cast here and are not counted.

  Renewal adds the reduction to the other variable-cast reductions; a skill that
  ignores status cast effects (Foresight itself) is neither reduced nor counted.
  Pre-renewal applies it as its own multiplier and counts every learned cast,
  Foresight included, unless the caster's DEX already makes the cast instant.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_memorize,
    no_dispel: false,
    no_save: true,
    permanent: true,
    properties: [:buff],
    icon: :memorize

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @charges 5
  @dex_scale 150

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok, instance |> put_state(:cast_time_reduction, 50) |> put_state(:charges, @charges)}
  end

  @impl true
  def on_committed_action({type, id}, instance, {:skill, skill_id}, _context) do
    with {:ok, stats} <- caster_stats(type, id),
         true <- Learned.learned_level(stats.progression.learned_skills, skill_id) > 0,
         {:ok, definition} <- Catalog.by_id(skill_id),
         true <- counted?(definition, stats) do
      spend(instance)
    else
      _not_counted -> {:ok, instance}
    end
  end

  def on_committed_action(_target, instance, _action, _context), do: {:ok, instance}

  defp spend(%{state: %{charges: charges}}) when charges <= 1, do: :remove
  defp spend(instance), do: {:ok, put_state(instance, :charges, instance.state.charges - 1)}

  defp counted?(definition, stats) do
    case GameMode.mode() do
      :renewal -> not definition.ignore_status_cast
      :pre_renewal -> definition.ignore_dex or stats.base_stats.dex < @dex_scale
    end
  end

  defp caster_stats(type, id) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, %{stats: %{progression: %{learned_skills: _}} = stats}, _pid}} ->
        {:ok, stats}

      _unavailable ->
        :error
    end
  end
end
