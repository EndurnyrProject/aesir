defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Monk.Tomoon do
  @moduledoc """
  Runs the final spiritual training test of the Monk job quest.

  ## Behavior

  - Briefs candidates and sends them into the spirit maze, or back in after a failure.
  - Rewards candidates who clear the maze with a Green Potion and sends them back to Moohae.
  - Warns everyone else not to cause trouble in the abbey.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Dino9021
    - Celest
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Lupus
    - Yor
    - Zephiris
    - Vicious
    - Silent

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "monk_test",
        x: 319,
        y: 139,
        dir: 1,
        sprite: 52,
        name: "Tomoon",
        scope: :shared,
        unique_name: "Tomoon#mk"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    quest = get_char_var(ctx, :MONK_Q, 0)

    cond do
      quest == 25 -> brief_maze(ctx)
      quest == 26 -> retry_maze(ctx)
      quest == 27 -> reward_potion(ctx)
      quest == 28 -> remind_moohae(ctx)
      true -> warn_troublemaker(ctx)
    end
  end

  defp brief_maze(ctx) do
    ctx
    |> mes("[Tomoon]")
    |> mes("Welcome young one.")
    |> mes("My name is Tomoon, I am in charge of the last test of spiritual training!")
    |> next()
    |> mes("[Tomoon]")
    |> mes("Now you don't need to be instructed any more than this:")
    |> mes("^990000Terminate every living thing in your way!^000000 That's all!")
    |> next()
    |> mes("[Tomoon]")
    |> mes(
      "While you're wandering around within the maze, if you encounter any evil creatures, just kill them! Release their tortured souls!!"
    )
    |> next()
    |> mes("[Tomoon]")
    |> mes(
      "Do not compare us to the weakling priests! We are monks and we will always be the strongest!!"
    )
    |> next()
    |> mes("[Tomoon]")
    |> mes("We are not like priests who cower behind the strength of others!")
    |> next()
    |> mes("[Tomoon]")
    |> mes(
      "Now, focus!! Keep your fists tight and your eyes open! It's time to show me what you got."
    )
    |> next()
    |> mes("[Tomoon]")
    |> mes("Let's see if you got what it takes to be a true monk!!")
    |> close()
    |> set_char_var(:MONK_Q, 26)
    |> changequest(3029, 3031)
    |> warp("monk_test", 88, 74)
  end

  defp retry_maze(ctx) do
    ctx
    |> mes("[Tomoon]")
    |> mes("Hmm... you failed?")
    |> mes("Cheer up! Failure is but a process to success!")
    |> mes("Go! Start again! Kill them all!!")
    |> close()
    |> warp("monk_test", 88, 74)
  end

  defp reward_potion(ctx) do
    ctx
    |> mes("[Tomoon]")
    |> mes("Excellent job!!")
    |> mes("I knew you'd make it through!")
    |> mes("Now...I will give you a secret potion which will double your physical strength.")
    |> next()
    |> give_item(506, 1)
    |> mes("Drink this potion and you will be able to become a monk!!!")
    |> mes("... now go back to sensei Moohae!!!")
    |> set_char_var(:MONK_Q, 28)
    |> changequest(3031, 3032)
    |> close()
  end

  defp remind_moohae(ctx) do
    ctx
    |> mes("[Tomoon]")
    |> mes("I already told you, go back to sensei Moohae!!!")
    |> close()
  end

  defp warn_troublemaker(ctx) do
    ctx
    |> mes("[Tomoon]")
    |> mes("....be quiet.")
    |> mes(".....")
    |> next()
    |> mes("[Tomoon]")
    |> mes("I will not allow anyone to cause any trouble in this abbey.")
    |> next()
    |> mes("[Tomoon]")
    |> mes("You'd better not be thinking about causing any trouble.")
    |> close()
  end
end
