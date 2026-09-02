defmodule Aesir.ZoneServer.Mmo.Skill.Origin do
  @moduledoc """
  Process-scoped identity of the skill currently executing and its caster.

  Nested invocations restore the outer origin when they return or raise.
  """

  alias Aesir.ZoneServer.Unit.Ref

  @key {__MODULE__, :current}

  @typedoc "The executing skill name and its caster, or a nil caster for NPC casts."
  @type t() :: %{skill: atom(), caster: Ref.t() | nil}

  @doc "Runs `fun` with the given skill origin, restoring the previous origin afterward."
  @spec with_skill(atom(), Ref.t() | nil, (-> result)) :: result when result: term()
  def with_skill(skill_name, caster_ref, fun) do
    previous = Process.get(@key)
    Process.put(@key, %{skill: skill_name, caster: caster_ref})

    try do
      fun.()
    after
      if previous,
        do: Process.put(@key, previous),
        else: Process.delete(@key)
    end
  end

  @doc "Returns the skill origin executing in this process, or nil outside an invocation."
  @spec current() :: t() | nil
  def current, do: Process.get(@key)
end
