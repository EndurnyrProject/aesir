defmodule Aesir.ZoneServer.Mmo.Skill do
  @moduledoc """
  The single entry point for defining a skill.

  Every skill is exactly one module that does `use Skill` once, passing its full
  static definition (the `skill_db` record - see `Skill.Definition`), and then
  composes one or more capability behaviours by declaring them and implementing
  their callbacks:

    * `Skill.Active` - the skill is actively cast (`cast/4`, optional `validate/4`)
    * `Skill.Passive` - the skill contributes passive effects (`atk_bonus/2`,
      `regen_contribution/2`, `skill_rider/4`)
    * `Skill.Ground` - the skill places a persistent ground unit (`on_place/1`,
      `on_interval/2`, optional `on_expire/1`)

  A skill declares only the behaviours it needs and can mix several at once.
  `use Skill` builds and stores the validated definition, exposes `skill_name/0`
  and `definition/0`, and - through a `@before_compile` hook - reads the declared
  `@behaviour`s to:

    * publish the skill's capabilities via `__skill_capabilities__/0` for
      `Skill.Catalog`;
    * fill in no-op defaults for the optional callbacks the module did not
      implement, so every consumer can call a capability's callbacks directly
      with no runtime reflection;
    * auto-derive the active `cast/4` for `target_type: :ground` skills, so a
      ground skill is a single module with no cast boilerplate.

  ## Example - a ground skill (active cast auto-derived)

      defmodule Aesir.ZoneServer.Mmo.Skills.WzStormgust do
        use Aesir.ZoneServer.Mmo.Skill,
          id: 89,
          name: :wz_stormgust,
          display_name: "Storm Gust",
          max_level: 10,
          target_type: :ground,
          damage_type: :damage,
          element: :water,
          knockback: 2,
          splash_radius: 2,
          hit_interval: 450,
          unit_duration: List.duplicate(4_500, 10)

        @behaviour Aesir.ZoneServer.Mmo.Skill.Ground

        @impl Aesir.ZoneServer.Mmo.Skill.Ground
        def on_place(group), do: ...

        @impl Aesir.ZoneServer.Mmo.Skill.Ground
        def on_interval(group, now), do: ...
      end
  """

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Passive
  alias Aesir.ZoneServer.Mmo.Skill.Unit

  @typedoc "A capability a skill module provides, derived from its declared behaviours."
  @type capability :: :active | :passive | :ground

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @before_compile Aesir.ZoneServer.Mmo.Skill

      @skill_definition Aesir.ZoneServer.Mmo.Skill.Definition.build!(opts, __MODULE__)

      @doc false
      def skill_name, do: @skill_definition.name

      @doc false
      def definition, do: @skill_definition
    end
  end

  defmacro __before_compile__(env) do
    mod = env.module
    definition = Module.get_attribute(mod, :skill_definition)
    behaviours = Module.get_attribute(mod, :behaviour) || []

    ground? = Ground in behaviours
    passive? = Passive in behaviours
    active? = Active in behaviours or ground?

    capabilities =
      Enum.filter([active? && :active, passive? && :passive, ground? && :ground], & &1)

    fragments =
      [auto_cast_default(mod, definition, ground?), validate_default(mod, active?, behaviours)] ++
        passive_defaults(mod, passive?) ++ [on_expire_default(mod, ground?)]

    quote do
      unquote_splicing(Enum.reject(fragments, &is_nil/1))

      @doc false
      def __skill_capabilities__, do: unquote(capabilities)
    end
  end

  # Ground skills are cast by placing their skill-unit; derive that cast/4 unless
  # the skill defines its own. Generated without @impl since ground skills declare
  # Skill.Ground, not Skill.Active.
  defp auto_cast_default(mod, definition, true = _ground?) do
    if not Module.defines?(mod, {:cast, 4}) do
      name = definition.name

      quote do
        def cast(caster, {:ground, x, y}, level, _definition) do
          case unquote(Unit).place(caster, unquote(name), level, {x, y}) do
            {:ok, _group} -> {:ok, caster}
            {:error, _reason} = error -> error
          end
        end
      end
    end
  end

  defp auto_cast_default(_mod, _definition, false), do: nil

  defp validate_default(mod, true = _active?, behaviours) do
    if not Module.defines?(mod, {:validate, 4}) do
      impl = if Active in behaviours, do: Active
      with_impl(impl, quote(do: def(validate(_caster, _target, _level, _definition), do: :ok)))
    end
  end

  defp validate_default(_mod, false, _behaviours), do: nil

  defp passive_defaults(_mod, false = _passive?), do: []

  defp passive_defaults(mod, true) do
    [
      default(mod, {:atk_bonus, 2}, Passive, quote(do: def(atk_bonus(_level, _ctx), do: 0))),
      default(mod, {:flee_bonus, 2}, Passive, quote(do: def(flee_bonus(_level, _ctx), do: 0))),
      default(mod, {:dex_bonus, 2}, Passive, quote(do: def(dex_bonus(_level, _ctx), do: 0))),
      default(mod, {:hit_bonus, 2}, Passive, quote(do: def(hit_bonus(_level, _ctx), do: 0))),
      default(mod, {:range_bonus, 2}, Passive, quote(do: def(range_bonus(_level, _ctx), do: 0))),
      default(
        mod,
        {:attack_proc, 2},
        Passive,
        quote(do: def(attack_proc(_level, _ctx), do: %{}))
      ),
      default(
        mod,
        {:regen_contribution, 2},
        Passive,
        quote(do: def(regen_contribution(_level, _ctx), do: %{}))
      ),
      default(
        mod,
        {:skill_rider, 4},
        Passive,
        quote(do: def(skill_rider(_target_skill, _target_level, _level, _ctx), do: :none))
      )
    ]
  end

  defp on_expire_default(mod, true = _ground?) do
    default(mod, {:on_expire, 1}, Ground, quote(do: def(on_expire(_group), do: :ok)))
  end

  defp on_expire_default(_mod, false), do: nil

  defp default(mod, {fun, arity}, behaviour, def_ast) do
    unless Module.defines?(mod, {fun, arity}), do: with_impl(behaviour, def_ast)
  end

  defp with_impl(nil, def_ast), do: def_ast

  defp with_impl(behaviour, def_ast) do
    quote do
      @impl unquote(behaviour)
      unquote(def_ast)
    end
  end
end
