defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Marvin do
  @moduledoc """
  Advises adventurers to plan their skill point spending carefully.

  ## Behavior

  - Varies one remark according to the visitor's sex.
  - Explains skill mastery levels and the limited supply of skill points.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 177,
        y: 18,
        dir: 2,
        sprite: 80,
        name: "Marvin",
        scope: :shared,
        unique_name: "Marvin#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx =
      ctx
      |> mes("[Marvin]")
      |> mes(
        "Whether it's schmoozing with a member of the opposite sex, or battling monsters, I gotta say, it's all about ^333399skills^000000."
      )
      |> next()
      |> mes("[Marvin]")
      |> mes(gendered_advice(ctx))

    ctx
    |> next()
    |> mes("[Marvin]")
    |> mes(
      "For most skills, the maximum level is level 10. It's easy to stress yourself out, since it takes so many points to completely master a skill. What skills should you choose?!"
    )
    |> next()
    |> mes("[Marvin]")
    |> mes(
      "After all, if you spend too many skill points on one skill, you might not be able to learn another. That's right, there's a limit to the number of total skill points you can earn."
    )
    |> next()
    |> mes("[Marvin]")
    |> mes(
      "But you know what? Not every skill is mastered at level 10. You can master some skills at only level 5. And even better, some skills are already mastered at level 1 or 2."
    )
    |> next()
    |> mes("[Marvin]")
    |> mes(
      "So relax and plan ahead, so you can master all the skills that you really want to master the most. Also, don't just put skill points into anything. Remember to use your skill points wisely."
    )
    |> close()
  end

  defp gendered_advice(ctx) do
    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
      "I can't help you much when it comes to the subject of talking to attractive women such as myself, but I can tell you a little more about skills that help in battle."
    else
      "I don't really have any advice for skills when it comes to talking to a cute guy, but I can let you in on what I know about skills that help in battle."
    end
  end
end
