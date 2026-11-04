defmodule Aesir.ZoneServer.Mmo.Skill.Unit.Handler do
  @moduledoc """
  Resolves a group's ground-skill handler module and invokes its callbacks.

  Every manager callback is a direct timer-driven invocation of the group's
  skill and caster, so it runs under that skill's `Origin` scope; the autocast
  flag of the cast that placed the group stays in that cast's process. Raises
  and throws inside a callback are captured as `{:error, reason}`.
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Origin
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  @doc "The group's handler module, explicit or resolved from the catalog."
  @spec for_group(Group.t()) :: {:ok, module()} | :error
  def for_group(%Group{handler: handler}) when not is_nil(handler), do: {:ok, handler}
  def for_group(%Group{skill_name: skill_name}), do: Catalog.ground_module_for(skill_name)

  @doc "The group's handler module, or `nil` when none resolves."
  @spec or_nil(Group.t()) :: module() | nil
  def or_nil(%Group{} = group) do
    case for_group(group) do
      {:ok, module} -> module
      :error -> nil
    end
  end

  @doc "Applies `callback` on `module` with `args` (the group first) under the skill's origin."
  @spec invoke(module(), atom(), [term(), ...]) :: {:ok, term()} | {:error, term()}
  def invoke(module, callback, args) do
    group = hd(args)

    result =
      Origin.with_skill(group.skill_name, {group.caster_type, group.caster_id}, fn ->
        apply(module, callback, args)
      end)

    {:ok, result}
  rescue
    error -> {:error, {error, __STACKTRACE__}}
  catch
    kind, reason -> {:error, {kind, reason, __STACKTRACE__}}
  end

  @doc "Logs a failed callback against its group."
  @spec log_error(Group.t(), atom(), term()) :: :ok
  def log_error(group, callback, reason) do
    Logger.error(
      "Skill.Unit.Manager callback=#{callback} failed skill=#{group.skill_name} " <>
        "group_id=#{group.group_id}: #{inspect(reason)}"
    )
  end
end
