defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AcolyteSkills.Cleric do
  @moduledoc """
  Acolyte Klift teaches the Holy Light quest skill in the Prontera church.

  ## Behavior

  - Explains the Holy Light skill and its required items and Job Level.
  - Teaches Holy Light to acolyte-line characters at Job Level 30 or higher, or to any Priest or
    Monk, in exchange for an Opal, a Crystal Blue, and a Rosary.
  - Turns away characters who already know the skill or who lack a requirement.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Masao
    - Euphy
    - Lupus
    - Silentdragon

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "prt_church", x: 173, y: 23, dir: 4, sprite: 79, name: "Cleric", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @holy_light 156
  @opal 727
  @crystal_blue 991
  @rosary 2608

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Acolyte Klift]")
      |> mes("Ahh . Brothers ! Does the task of")
      |> mes("caring for out lost sheep burden")
      |> mes("and tire you ?")
      |> mes("I am here to assist you.")
      |> next()
      |> select([
        "^3355FF' About acolyte's hidden ability '^000000 ..",
        "^3355FF' Holy light '^000000 training",
        "End conversation"
      ])

    case choice do
      1 -> explain_skill(ctx)
      2 -> training(ctx)
      3 -> farewell(ctx)
      _ -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp explain_skill(ctx) do
    ctx
    |> mes("[Acolyte Klift]")
    |> mes("Our members of the clergy")
    |> mes("naturally learn a skill as")
    |> mes("as they mature. As they approach ")
    |> mes("their senior years as an acolyte")
    |> mes("this special skill.")
    |> next()
    |> mes("[Acolyte Klift]")
    |> mes("Faced with great danger and")
    |> mes("an endless struggle with evil,")
    |> mes("our brethren are much in need of assistance.")
    |> mes("^3355FF' Holy Light '^000000 is that skill.")
    |> mes("To gain this ability for yourself,")
    |> mes("takes some work.")
    |> next()
    |> mes("[Acolyte Klift]")
    |> mes("To gain the skill, you must find these items.")
    |> mes("^FF33551 Opal^000000")
    |> mes("^FF33551 Crystal Blue^000000")
    |> mes("^FF33551 Rosary^000000 ")
    |> next()
    |> mes("[Acolyte Klift]")
    |> mes("In order to be able to even use this skill,")
    |> mes("one must be have sufficient experience.")
    |> mes("^FF3355 Job Level 30^000000")
    |> mes("is required to learn this skill.")
    |> next()
    |> mes("[Acolyte Klift]")
    |> mes("As for a priest, because of their")
    |> mes("already vast amount of experience,")
    |> mes("they are able to gain this skill at any")
    |> mes("job level.")
    |> close()
  end

  defp training(ctx) do
    cond do
      getskilllv(ctx, @holy_light) == 1 -> already_known(ctx)
      qualified?(ctx) -> teach(ctx)
      true -> not_ready(ctx)
    end
  end

  defp qualified?(ctx) do
    count_item(ctx, @opal) > 0 and count_item(ctx, @crystal_blue) > 0 and
      count_item(ctx, @rosary) > 0 and
      (job_level(ctx) > 29 or
         (Rathena.job_id(base_job(ctx)) == Rathena.job_id(:priest) or
            Rathena.job_id(base_job(ctx)) == Rathena.job_id(:monk))) and
      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:acolyte)
  end

  defp already_known(ctx) do
    ctx
    |> mes("[Acolyte Klift]")
    |> mes("Brother, you already possess")
    |> mes("the skill of ` Holy Light '.")
    |> mes("You cannot gain a skill you")
    |> mes("already possess ..")
    |> mes("I pray that you are using")
    |> mes("this skill for the work of good . .")
    |> close()
  end

  defp teach(ctx) do
    ctx
    |> mes("[Acolyte Klift]")
    |> mes("Your faith has proven worthy")
    |> mes("for you to gain the ' Holy Light ' skill.")
    |> mes("Your skill is adequate")
    |> mes("to use this skill.")
    |> mes("Use it wisely. . .")
    |> next()
    |> delitem(@opal, 1)
    |> delitem(@crystal_blue, 1)
    |> delitem(@rosary, 1)
    |> skill(@holy_light, 1, :permanent)
    |> mes("[Acolyte Klift]")
    |> mes("You now know ' Holy Light '")
    |> mes("May you use this skill only in the")
    |> mes("best conduct . . . . .")
    |> close()
  end

  defp not_ready(ctx) do
    ctx
    |> mes("[Acolyte Klift]")
    |> mes("Oh, it is clear. . .")
    |> mes("You are not yet ready to")
    |> mes("receive the ' Holy Light ' skill.")
    |> next()
    |> mes("[Acolyte Klift]")
    |> mes("You should listen carefully to what")
    |> mes("is necessary for this skill.")
    |> mes("If you listen closely,")
    |> mes("you may learn what you lack.")
    |> mes("So that you may improve upon yourself.")
    |> close()
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Acolyte Klift]")
    |> mes(". . . . .")
    |> mes("I understand your zeal.")
    |> mes("You have much time yet to")
    |> mes("practice and gain experience.")
    |> mes("Blessings upon you . . . . .")
    |> close()
  end
end
