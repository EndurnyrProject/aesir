defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Memorize do
  @moduledoc """
  Foresight (SC_MEMORIZE). The holder's next five casts of skills they have
  learned take 50% less variable cast time; the status ends once the fifth has
  resolved. Foresight itself, item-granted and automatic casts are not
  counted, and a cast cancelled mid-way keeps its charge.

  Renewal adds the reduction to the other variable-cast reductions (Bragi);
  pre-renewal applies it as its own multiplier.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_memorize,
    no_dispel: false,
    no_save: true,
    permanent: true,
    properties: [:buff],
    icon: :memorize

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @charges 5
  @foresight 403

  @impl true
  def on_apply(_target, instance, _context) do
    {:ok, instance |> put_state(:cast_time_reduction, 50) |> put_state(:charges, @charges)}
  end

  @impl true
  def on_committed_action(_target, instance, {:skill_resolved, @foresight}, _context),
    do: {:ok, instance}

  def on_committed_action({type, id}, instance, {:skill_resolved, skill_id}, _context) do
    cond do
      not learned?(type, id, skill_id) -> {:ok, instance}
      instance.state.charges <= 1 -> :remove
      true -> {:ok, put_state(instance, :charges, instance.state.charges - 1)}
    end
  end

  def on_committed_action(_target, instance, _action, _context), do: {:ok, instance}

  defp learned?(type, id, skill_id) do
    case UnitRegistry.get_unit(type, id) do
      {:ok, {_module, %{stats: %{progression: %{learned_skills: skills}}}, _pid}} ->
        Learned.learned_level(skills, skill_id) > 0

      _unavailable ->
        false
    end
  end
end
