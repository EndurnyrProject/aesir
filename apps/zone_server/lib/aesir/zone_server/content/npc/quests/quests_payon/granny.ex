defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsPayon.Granny do
  @moduledoc """
  A Payon grandmother who trades her Pretend Murdered keepsake for 4 Skirt of Virgin.

  ## Behavior

  - Refuses to talk while the player is carrying too much.
  - With 4 Skirt of Virgin the player can hand them over for a Pretend Murdered, or refuse.
  - Otherwise she explains that she needs 4 Skirt of Virgin to make festival clothing.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - Silent
    - Samuray22
    - L0ne_W0lf
    - JohnnyPlayy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "payon_in01", x: 99, y: 72, dir: 4, sprite: 103, name: "Granny", scope: :shared}
    ]

  @speaker "[Granny]"

  @skirt_of_virgin 1049
  @pretend_murdered 2293

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{908, 1}]) == 0 ->
        ctx
        |> mes(
          "^3355FFWait a second! Right now, you're carrying too many items with you. Please come back after putting some of your things into Kafra Storage.^000000"
        )
        |> close()

      count_item(ctx, @skirt_of_virgin) >= 4 ->
        ask_for_skirts(ctx)

      true ->
        ctx
        |> mes(@speaker)
        |> mes(
          "I gather Mushrooms on the Mountain of Payon everyday. Time passes and before I know it, it's already fesitval season. I wish I could make clothing for my family this time of the year."
        )
        |> next()
        |> mes(@speaker)
        |> mes("...")
        |> mes("But for that, I need ^3355FF4 Skirt of Virgin^000000...")
        |> next()
        |> mes(@speaker)
        |> mes(
          "Young traveler, please help me. When you find some ^3355FFSkirt of Virgin^000000, please bring them to me. I'd really appreciate it..."
        )
        |> close()
    end
  end

  defp ask_for_skirts(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@speaker)
      |> mes("I wish I could make some clothing for my grandchildren for the festival season...")
      |> next()
      |> mes(@speaker)
      |> mes(
        "Oh! Would you give me your ^3355FFSkirt of Virgin^000000? I'd need four of them. Please, I'm begging you."
      )
      |> next()
      |> select(["Alright.", "No way!"])

    case choice do
      1 ->
        ctx
        |> delitem(@skirt_of_virgin, 4)
        |> mes(@speaker)
        |> mes("Oh! Thank you so much~ Now I can make some clothes for Kitty Cutty~")
        |> next()
        |> mes(@speaker)
        |> mes(
          "Ah, Wait! I almost forgot. I was quite a popular actress back in my youth. My actor friends gave me a wedding present when I left the Troupe. I've kept it to remind me of those precious times."
        )
        |> next()
        |> mes(@speaker)
        |> mes("If it's okay...")
        |> mes("I'd like to give you this.")
        |> next()
        |> give_item(@pretend_murdered, 1)
        |> mes(@speaker)
        |> mes("Goodbye, adventurer~!")
        |> mes("Thank you for making an old woman so happy...")
        |> close()

      2 ->
        ctx
        |> mes(@speaker)
        |> mes(
          "*Sigh* How can I get ^3355FFSkirt of Virgin^000000 by myself? I'm just so weak and feeble, even rolling in my rocking chair exhausts me. *Sniff* All I want is to make my grandchildren happy..."
        )
        |> close()

      _ ->
        ctx
    end
  end
end
