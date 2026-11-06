defmodule Aesir.ZoneServer.Content.Npc.Functions.FGetplatinumskills do
  @moduledoc """
  Grants the platinum skills that belong to the character's class.

  ## Behavior

  First Aid is granted to every class. The first class tree adds its own platinum skills, and the
  second class adds one more set on top. A Super Novice skips the Novice Trick Dead skill.
  Merchants additionally receive Cart Decoration on the newer client versions.

  ## Credits

  - Original from rAthena, authors and Contributors
    - mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @first_aid 142
  @trick_dead 143

  @class_skills %{
    swordman: [144, 145, 146],
    mage: [157],
    archer: [147, 148],
    acolyte: [156],
    thief: [149, 150, 151, 152]
  }

  @merchant_skills [153, 154, 155]

  @job_skills %{
    knight: [1001],
    priest: [1014],
    wizard: [1006],
    blacksmith: [1012, 1013],
    hunter: [1009],
    assassin: [1003, 1004],
    crusader: [1002],
    monk: [1015, 1016],
    sage: [1007, 1008, 1017, 1018, 1019],
    rogue: [1005],
    alchemist: [238],
    bard: [1010],
    dancer: [1011]
  }

  @doc "Callable rAthena global function `F_GetPlatinumSkills`; grants the class platinum skills."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), nil}
  def call(ctx, _args) do
    ctx = ctx |> skill(@first_aid, 1, :permanent) |> grant_class_skills() |> grant_job_skills()
    {ctx, nil}
  end

  defp grant_class_skills(ctx) do
    case base_class(ctx) do
      :novice -> grant_novice_skills(ctx)
      :merchant -> grant_merchant_skills(ctx)
      base_class -> grant(ctx, Map.get(@class_skills, base_class, []))
    end
  end

  defp grant_novice_skills(ctx) do
    if class(ctx) == :super_novice, do: ctx, else: skill(ctx, @trick_dead, 1, :permanent)
  end

  defp grant_merchant_skills(ctx) do
    ctx = grant(ctx, @merchant_skills)

    if get_char_var(ctx, :PACKETVER, 0) >= 20_150_826,
      do: skill(ctx, :mc_cartdecorate, 1, :permanent),
      else: ctx
  end

  defp grant_job_skills(ctx), do: grant(ctx, Map.get(@job_skills, base_job(ctx), []))

  defp grant(ctx, skill_ids), do: Enum.reduce(skill_ids, ctx, &skill(&2, &1, 1, :permanent))
end
