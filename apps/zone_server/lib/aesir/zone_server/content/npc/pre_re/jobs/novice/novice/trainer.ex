defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.Novice.Novice.Trainer do
  @moduledoc """
  Hoffman's battle advice and transfers within the pre-renewal combat grounds.

  ## Behavior

  - Explains combat training and offers more challenging training grounds.
  - Chooses transfer destinations according to the trainer identity and selected challenge.

  ## Credits

  - Original from rAthena, authors: Dr.Evil and MasterOfMuppets.
  - Elixir adaptation: transpiled and refactored by an LLM.
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "new_1-3",
        x: 95,
        y: 30,
        dir: 4,
        sprite: 84,
        name: "Trainer",
        unique_name: "NovHoffman"
      },
      %{
        map: "new_2-3",
        x: 95,
        y: 30,
        dir: 4,
        sprite: 84,
        name: "Trainer",
        unique_name: "Trainer#nv2"
      },
      %{
        map: "new_3-3",
        x: 95,
        y: 30,
        dir: 4,
        sprite: 84,
        name: "Trainer",
        unique_name: "Trainer#nv3"
      },
      %{
        map: "new_4-3",
        x: 95,
        y: 30,
        dir: 4,
        sprite: 84,
        name: "Trainer",
        unique_name: "Trainer#nv4"
      },
      %{
        map: "new_5-3",
        x: 95,
        y: 30,
        dir: 4,
        sprite: 84,
        name: "Trainer",
        unique_name: "Trainer#nv5"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Hoffman]")
      |> mes("Hey there~")
      |> mes("I'm here to provide")
      |> mes("you with a little instruction.")
      |> next()
      |> mes("[Hoffman]")
      |> mes("These monsters are all weak")
      |> mes("and easy to kill. But be careful,")
      |> mes("a lot of them are aggressive")
      |> mes("and out for blood!")
      |> next()
      |> mes("[Hoffman]")
      |> mes(
        "If you think monsters here are too weak for you, I can send you to another training ground where the monsters are stronger than the ones over here."
      )
      |> next()
      |> mes("[Hoffman]")
      |> mes("But don't worry so much,")
      |> mes("They're not impossible for")
      |> mes("Novices. So would you")
      |> mes("like to try?")
      |> next()
      |> select(["I do want more of a challenge~", "I wanna fight tough monsters!", "Cancel"])

    guide(ctx, choice)
  end

  defp guide(ctx, 1) do
    ctx =
      ctx
      |> mes("[Hoffman]")
      |> mes("I see, then let me guide")
      |> mes("you to a training ground that has stronger monsters. May God be with you...")
      |> next()

    destination =
      if strnpcinfo(ctx, 2) == "nv1" do
        Enum.at(["new_3-3", "new_2-3"], :rand.uniform(2) - 1)
      else
        "new_1-3"
      end

    warp(ctx, destination, 96, 21)
  end

  defp guide(ctx, 2) do
    ctx =
      ctx
      |> mes("[Hoffman]")
      |> mes("You must like ")
      |> mes("rough challenges,")
      |> mes("don't you? Please")
      |> mes("be careful, it can get")
      |> mes("pretty difficult...")
      |> next()

    destinations =
      if strnpcinfo(ctx, 2) in ["nv1", "nv2", "nv3"] do
        ["new_5-3", "new_4-3"]
      else
        ["new_3-3", "new_2-3"]
      end

    warp(ctx, Enum.at(destinations, :rand.uniform(2) - 1), 96, 21)
  end

  defp guide(ctx, 3) do
    ctx
    |> mes("[Hoffman]")
    |> mes("Hmm...?")
    |> mes("Are you worried about going")
    |> mes(
      "to more challenging places? That's understandable, since you're still a new adventurer. Good luck~"
    )
    |> close()
  end

  defp guide(ctx, _choice), do: ctx
end
