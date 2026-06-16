defmodule Aesir.ZoneServer.Mmo.Skill.Passive do
  @moduledoc """
  Behaviour for passive skill implementations.

  Each passive skill module declares its name with `use Skill.Passive, skill: :name`
  and overrides only the channels it participates in. The three channel callbacks
  (`atk_bonus/2`, `regen_contribution/2`, `skill_rider/4`) are optional and default
  to no-ops via the `__using__/1` macro.
  """

  @typedoc """
  Context passed to passive callbacks, describing the player's current state
  relevant for passive skill computations.
  """
  @type ctx :: %{
          weapon_type: atom(),
          base_level: pos_integer(),
          job_level: non_neg_integer(),
          max_hp: pos_integer(),
          max_sp: pos_integer(),
          vit: non_neg_integer(),
          int: non_neg_integer()
        }

  @callback skill_name() :: atom()

  @doc "Returns a flat ATK bonus contributed by this passive at the given level."
  @callback atk_bonus(level :: pos_integer(), ctx()) :: integer()

  @doc "Returns a map of regen contributions from this passive at the given level."
  @callback regen_contribution(level :: pos_integer(), ctx()) ::
              %{
                optional(:skill_hp_regen) => integer(),
                optional(:skill_sp_regen) => integer(),
                optional(:allow_while_moving) => boolean()
              }

  @doc """
  Returns a skill rider to apply after `target_skill` is used, or `:none` if
  this passive does not modify the given skill.
  """
  @callback skill_rider(
              target_skill :: atom(),
              target_skill_level :: pos_integer(),
              passive_level :: pos_integer(),
              ctx()
            ) :: :none | {:apply_status, atom(), keyword()}

  @optional_callbacks atk_bonus: 2, regen_contribution: 2, skill_rider: 4

  defmacro __using__(opts) do
    skill = Keyword.fetch!(opts, :skill)

    quote do
      @behaviour Aesir.ZoneServer.Mmo.Skill.Passive

      @impl true
      def skill_name, do: unquote(skill)

      @impl true
      def atk_bonus(_level, _ctx), do: 0

      @impl true
      def regen_contribution(_level, _ctx), do: %{}

      @impl true
      def skill_rider(_target_skill, _target_skill_level, _passive_level, _ctx), do: :none

      defoverridable atk_bonus: 2, regen_contribution: 2, skill_rider: 4
    end
  end
end
