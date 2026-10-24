defmodule Aesir.ZoneServer.Mmo.Skill.Origin do
  @moduledoc """
  Process-scoped identity of the skill currently executing and its caster, plus
  the caster's runtime autocast flag.

  The identity (skill, caster, invocation kind) is a stack: nested invocations
  restore the outer identity when they return or raise. The autocast flag is
  tracked separately and is never restored: it is set when an equipment proc
  starts executing and reset when it returns, so a proc that runs inside an
  already flagged invocation leaves the flag cleared. Changing the nested
  identity alone neither grants nor clears the flag.

  The flag belongs to one caster: `autocast?/1` is true only for the caster
  whose proc set it, so an unrelated caster executing in the same process never
  inherits the exemption.

  `collect_skill_attacks/1` observes whether the invocation it wraps executed a
  skill attack (`mark_skill_attack/0`), which is how the reference's own
  `skill_attack` reaches its post-hit rules. A mark is only recorded inside a
  collection, so an attack executed outside a skill invocation - an ordinary
  swing, a field unit's later tick - never reaches one.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Ref

  @identity {__MODULE__, :current}
  @flag {__MODULE__, :autocast_flag}
  @attack {__MODULE__, :skill_attack}

  @typedoc "How an invocation entered the runtime and whether it sets the autocast flag."
  @type scope :: %{invocation: Active.cast_origin(), autocast_flag?: boolean()}

  @typedoc """
  The executing skill, its caster (nil for NPC casts), the invocation kind and
  the caster's live autocast flag.
  """
  @type t() :: %{
          skill: atom(),
          caster: Ref.t() | nil,
          invocation: Active.cast_origin(),
          autocast_flag?: boolean()
        }

  @direct_scope %{invocation: :direct, autocast_flag?: false}

  @doc """
  Runs `fun` as a direct invocation of the given skill and caster, restoring the
  previous identity afterward. The autocast flag is left untouched, so a direct
  invocation nested in a flagged proc keeps that caster's flag.
  """
  @spec with_skill(atom(), Ref.t() | nil, (-> result)) :: result when result: term()
  def with_skill(skill_name, caster_ref, fun),
    do: with_skill(skill_name, caster_ref, @direct_scope, fun)

  @doc """
  Runs `fun` with the given skill identity and invocation scope.

  The previous identity is restored when `fun` returns or raises. A scope with
  `autocast_flag?: true` sets the caster's autocast flag on entry and resets it
  on exit; a scope without it leaves the flag as it was.
  """
  @spec with_skill(atom(), Ref.t() | nil, scope(), (-> result)) :: result when result: term()
  def with_skill(skill_name, caster_ref, %{invocation: invocation, autocast_flag?: flag?}, fun) do
    previous = Process.get(@identity)
    Process.put(@identity, %{skill: skill_name, caster: caster_ref, invocation: invocation})
    if flag?, do: set_autocast_flag(caster_ref, true)

    try do
      fun.()
    after
      if previous,
        do: Process.put(@identity, previous),
        else: Process.delete(@identity)

      if flag?, do: set_autocast_flag(caster_ref, false)
    end
  end

  @doc "Returns the skill origin executing in this process, or nil outside an invocation."
  @spec current() :: t() | nil
  def current do
    case Process.get(@identity) do
      nil -> nil
      %{caster: caster} = identity -> Map.put(identity, :autocast_flag?, autocast?(caster))
    end
  end

  @doc "Whether `caster_ref`'s autocast flag is set in this process."
  @spec autocast?(Ref.t() | nil) :: boolean()
  def autocast?(nil), do: false
  def autocast?(caster_ref), do: Process.get(@flag) == caster_ref

  @doc """
  Runs `fun` while collecting whether a skill attack executed in this process.

  Returns `{result, attacked?}`. The previous collection, if any, is restored
  when `fun` returns or raises, so a nested invocation never consumes its
  caller's observation.
  """
  @spec collect_skill_attacks((-> result)) :: {result, boolean()} when result: term()
  def collect_skill_attacks(fun) do
    previous = Process.get(@attack)
    Process.put(@attack, false)

    try do
      result = fun.()
      {result, Process.get(@attack) == true}
    after
      if previous == nil,
        do: Process.delete(@attack),
        else: Process.put(@attack, previous)
    end
  end

  @doc """
  Records that a skill attack executed in the current collection.

  A call outside a collection is discarded: the attack is not part of a skill
  invocation, so the invocation-scoped rules never see it.
  """
  @spec mark_skill_attack() :: :ok
  def mark_skill_attack do
    if Process.get(@attack) != nil, do: Process.put(@attack, true)
    :ok
  end

  @doc """
  Sets or resets `caster_ref`'s autocast flag.

  Resetting only clears a flag held by that same caster; a NPC cast (nil
  caster) has no flag.
  """
  @spec set_autocast_flag(Ref.t() | nil, boolean()) :: :ok
  def set_autocast_flag(nil, _flag?), do: :ok

  def set_autocast_flag(caster_ref, true) do
    Process.put(@flag, caster_ref)
    :ok
  end

  def set_autocast_flag(caster_ref, false) do
    if Process.get(@flag) == caster_ref, do: Process.delete(@flag)
    :ok
  end
end
