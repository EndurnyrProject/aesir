defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.ToolShopMaster do
  @moduledoc """
  Wang Chuiyi directs the player to the medicine storage.

  ## Behavior

  - His dialogue changes with the doctor quest, including directions to the storage keeper.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in02",
        x: 248,
        y: 166,
        dir: 2,
        sprite: 824,
        name: "Tool Shop Master",
        scope: :shared,
        unique_name: "Tool Shop Master#lou"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :ch_par, 0)

    cond do
      progress < 2 ->
        ctx
        |> mes("[Wang Chuiyi]")
        |> mes("My business hasn't been doing")
        |> mes(
          "well recently. And what is wrong with this weather? I don't know what's going on with the world..."
        )
        |> close()

      progress == 2 ->
        ask_about_errand(ctx)

      progress == 4 ->
        ctx
        |> mes("[Wang Chuiyi]")
        |> mes(
          "What? He didn't give you the stuff you need? Huh, I guess you did something he didn't like. I can't help you if that's the case."
        )
        |> close()

      progress < 10 ->
        ctx
        |> mes("[Wang Chuiyi]")
        |> mes(
          "I can't understand why outsiders continue to travel here to Luoyang despite the weather. I'm also getting tired of keeping my business here. Sooner or later,"
        )
        |> mes("I may have to leave.")
        |> close()

      true ->
        ctx
        |> mes("[Wang Chuiyi]")
        |> mes(
          "God, what is wrong with this weather?! I wish the Cloud God would bring the rainy season, but it doesn't seem possible."
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ask_about_errand(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Wang Chuiyi]")
      |> mes("Darn it!")
      |> mes("I hate this")
      |> mes("weather...!")
      |> next()
      |> mes("[Wang Chuiyi]")
      |> mes("Um? Can I help")
      |> mes("you with anything?")
      |> emotion(:question)
      |> next()
      |> select([
        "I'm here to get something for the doctor...",
        "I agree, the weather really is bad."
      ])

    if choice == 1 do
      ctx
      |> mes("[Wang Chuiyi]")
      |> mes("Huh?")
      |> mes("An errand for the doctor?")
      |> mes("She must have run out of")
      |> mes("medicine again. Go ahead")
      |> mes("and check the storage.")
      |> next()
      |> mes("[Wang Chuiyi]")
      |> mes("You can find the storage on")
      |> mes(
        "the opposite side of this building. There, you'll see a guy named Jiang Xiayou. Go ahead and ask him for the stuff you need."
      )
      |> set_char_var(:ch_par, 3)
      |> changequest(11044, 11045)
      |> close()
    else
      ctx
      |> mes("[Wang Chuiyi]")
      |> mes("Tell me about it. This weather keeps stressing me out. Damn,")
      |> mes("I don't think I'll live very long if I keep getting aggravated like")
      |> mes("this by the weather...")
      |> close()
    end
  end
end
