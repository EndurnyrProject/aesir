defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.PhraconGuy do
  @moduledoc """
  Explains where to obtain Phracon and how it is used.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldebaran",
        x: 117,
        y: 181,
        dir: 4,
        sprite: 48,
        name: "Phracon Guy",
        scope: :shared,
        unique_name: "Phracon Guy#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Joy]")
      |> mes(
        "Level 1 weapons, which are the lowest grade, need a metal named ^3355FFPhracon^000000 in order to be upgraded."
      )
      |> next()
      |> select(["About Phracon", "Advice about Phracon", "End Conversation"])

    case choice do
      1 ->
        ctx
        |> mes("[Joy]")
        |> mes(
          "Phracon is a pretty common metal and can be found all over the Midgard continent."
        )
        |> next()
        |> mes("[Joy]")
        |> mes(
          "Although it lacks the strength of other metals, it's easy to find and obtain. You can get Phracons by killing monsters or by buying them in Forging Shops in towns."
        )
        |> next()
        |> mes("[Joy]")
        |> mes(
          "When you no longer need Phracons because you are using higher level weapons, you can sell them for some zeny!"
        )
        |> close()

      2 ->
        ctx
        |> mes("[Joy]")
        |> mes(
          "Well, I hear lots of monsters carry Phracons and will drop them once killed. Why don't you go hunting for them?"
        )
        |> next()
        |> mes("[Joy]")
        |> mes(
          "It shouldn't be too difficult. Once I found a Phracon that dropped after killing a Bebe Savage! But if you're desperate, you can always buy them at the Forging Shop."
        )
        |> close()

      3 ->
        ctx |> mes("[Joy]") |> mes("Good luck with finding Phracons!") |> close()

      _ ->
        ctx
    end
  end
end
