defmodule Aesir.ZoneServer.Mmo.Skill do
  @moduledoc """
  The single entry point for defining a skill.

  Every skill is exactly one module that does `use Skill` once, passing its full
  static definition (the `skill_db` record - see `Skill.Definition`), and then
  composes one or more capability behaviours by declaring them and implementing
  their callbacks:

    * `Skill.Active` - the skill is actively cast (`cast/4`, optional `validate/4`)
    * `Skill.Passive` - the skill contributes passive effects (`atk_bonus/2`, `critical_bonus/2`,
      `regen_contribution/2`, `skill_rider/4`)
    * `Skill.Ground` - the skill places a persistent ground unit (`on_place/1`,
      `on_interval/2`, optional `on_expire/1`)
    * `Skill.Menu` - the skill's cast opens a `SkillMenu` and acts on the reply
      (`on_menu_reply/3`)
    * `Skill.Performance` - the skill is a song or dance (`dynamic_cost/4`)
    * `Skill.Ensemble` - the skill is an ensemble

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

      defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzStormgust do
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
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Menu
  alias Aesir.ZoneServer.Mmo.Skill.Passive
  alias Aesir.ZoneServer.Mmo.Skill.Performance
  alias Aesir.ZoneServer.Mmo.Skill.Unit

  @typedoc "A capability a skill module provides, derived from its declared behaviours."
  @type capability :: :active | :passive | :ground | :menu | :performance | :ensemble

  @doc """
  Schedules a deferred skill effect on the caller.

  Sends `{:skill, {:deferred, module, payload}}` to the calling process after
  `delay_ms`, so the delayed effect runs later inside the caster's own session
  process. It must be called from within that session (so `self()` is the
  session pid); this keeps the timer's ordering and deadlock semantics
  identical to an inline `Process.send_after/3`. The receiving session invokes
  `module.deferred(payload, caster_state)`.
  """
  @spec defer(module(), term(), non_neg_integer()) :: reference()
  def defer(module, payload, delay_ms) do
    Process.send_after(self(), {:skill, {:deferred, module, payload}}, delay_ms)
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @before_compile Aesir.ZoneServer.Mmo.Skill

      @skill_definition Aesir.ZoneServer.Mmo.Skill.Definition.build!(opts, __MODULE__)

      # Whether this module explicitly passed `requires:` (vs relying on the default).
      # Recorded at compile time so the mob-skill requirement manifest can detect a
      # missing annotation robustly (no runtime source inspection, Mimic-safe).
      @requires_declared Keyword.has_key?(opts, :requires)

      @doc false
      def __requires_declared__, do: @requires_declared

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
    menu? = Menu in behaviours
    performance? = Performance in behaviours
    ensemble? = Ensemble in behaviours
    active? = Active in behaviours or ground?

    capabilities =
      for {enabled?, capability} <- [
            {active?, :active},
            {passive?, :passive},
            {ground?, :ground},
            {menu?, :menu},
            {performance?, :performance},
            {ensemble?, :ensemble}
          ],
          enabled?,
          do: capability

    fragments =
      [
        auto_cast_default(mod, definition, ground?, behaviours),
        validate_default(mod, active?, behaviours)
      ] ++
        passive_defaults(mod, passive?) ++ [on_expire_default(mod, ground?)]

    quote do
      unquote_splicing(Enum.reject(fragments, &is_nil/1))

      @doc false
      def __skill_capabilities__, do: unquote(capabilities)
    end
  end

  # Ground skills are cast by placing their skill-unit; derive cast callbacks
  # unless the skill defines its own. Generated without @impl since ground skills
  # declare Skill.Ground, not Skill.Active.
  defp auto_cast_default(mod, definition, true = _ground?, behaviours) do
    cast? = Module.defines?(mod, {:cast, 4})

    origin_ast =
      origin_cast_default(
        definition,
        cast?,
        Active in behaviours,
        Module.defines?(mod, {:cast_with_origin, 5})
      )

    cast_ast = direct_cast_default(cast?)

    quote do
      unquote(origin_ast)
      unquote(cast_ast)
    end
  end

  defp auto_cast_default(_mod, _definition, false, _behaviours), do: nil

  defp origin_cast_default(_definition, _cast?, _active?, true = _defined?), do: nil

  defp origin_cast_default(definition, cast?, active?, false = _defined?) do
    impl = if active?, do: Active
    with_impl(impl, origin_cast_body(definition, cast?))
  end

  defp origin_cast_body(_definition, true = _cast?) do
    quote do
      def cast_with_origin(caster, target, level, definition, _origin) do
        cast(caster, target, level, definition)
      end
    end
  end

  defp origin_cast_body(definition, false = _cast?) do
    name = definition.name

    quote do
      def cast_with_origin(caster, {:ground, x, y}, level, _definition, origin) do
        paid_return? =
          origin == :normal and Map.has_key?(caster, :character_id) and
            unquote(definition.item_cost != [])

        case unquote(Unit).place(caster, unquote(name), level, {x, y},
               origin: origin,
               state: %{paid_return?: paid_return?}
             ) do
          {:ok, _group} -> {:ok, caster}
          {:error, _reason} = error -> error
        end
      end
    end
  end

  defp direct_cast_default(true = _cast?), do: nil

  defp direct_cast_default(false = _cast?) do
    quote do
      def cast(caster, target, level, definition) do
        cast_with_origin(caster, target, level, definition, :direct)
      end
    end
  end

  defp validate_default(mod, true = _active?, behaviours) do
    if not Module.defines?(mod, {:validate, 4}) do
      impl = if Active in behaviours, do: Active
      with_impl(impl, quote(do: def(validate(_caster, _target, _level, _definition), do: :ok)))
    end
  end

  defp validate_default(_mod, false, _behaviours), do: nil

  @passive_channel_defaults [
    {:atk_bonus, 2, quote(do: def(atk_bonus(_level, _ctx), do: 0))},
    {:right_hand_damage_rate, 2, quote(do: def(right_hand_damage_rate(_level, _ctx), do: 0))},
    {:left_hand_damage_rate, 2, quote(do: def(left_hand_damage_rate(_level, _ctx), do: 0))},
    {:katar_secondary_rate, 2, quote(do: def(katar_secondary_rate(_level, _ctx), do: 0))},
    {:hit_bonus, 2, quote(do: def(hit_bonus(_level, _ctx), do: 0))},
    {:critical_bonus, 2, quote(do: def(critical_bonus(_level, _ctx), do: 0))},
    {:flee_bonus, 2, quote(do: def(flee_bonus(_level, _ctx), do: 0))},
    {:dex_bonus, 2, quote(do: def(dex_bonus(_level, _ctx), do: 0))},
    {:str_bonus, 2, quote(do: def(str_bonus(_level, _ctx), do: 0))},
    {:range_bonus, 2, quote(do: def(range_bonus(_level, _ctx), do: 0))},
    {:max_weight_bonus, 2, quote(do: def(max_weight_bonus(_level, _ctx), do: 0))},
    {:aspd_bonus, 2, quote(do: def(aspd_bonus(_level, _ctx), do: 0))},
    {:int_bonus, 2, quote(do: def(int_bonus(_level, _ctx), do: 0))},
    {:max_hp_bonus, 2, quote(do: def(max_hp_bonus(_level, _ctx), do: 0))},
    {:max_sp_rate_bonus, 2, quote(do: def(max_sp_rate_bonus(_level, _ctx), do: 0))},
    {:zeny_cost_reduction, 2, quote(do: def(zeny_cost_reduction(_level, _ctx), do: 0))},
    {:steal_proc, 2, quote(do: def(steal_proc(_level, _ctx), do: %{}))},
    {:shop_discount_pct, 2, quote(do: def(shop_discount_pct(_level, _ctx), do: 0))},
    {:attack_proc, 2, quote(do: def(attack_proc(_level, _ctx), do: %{}))},
    {:after_normal_hit, 2, quote(do: def(after_normal_hit(_player_state, _hit), do: :ok))},
    {:regen_contribution, 2, quote(do: def(regen_contribution(_level, _ctx), do: %{}))},
    {:skill_rider, 4,
     quote(do: def(skill_rider(_target_skill, _target_level, _level, _ctx), do: :none))}
  ]

  defp passive_defaults(_mod, false = _passive?), do: []

  defp passive_defaults(mod, true) do
    Enum.map(@passive_channel_defaults, fn {name, arity, def_ast} ->
      default(mod, {name, arity}, Passive, def_ast)
    end)
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
