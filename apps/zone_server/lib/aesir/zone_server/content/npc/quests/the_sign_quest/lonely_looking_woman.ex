defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.LonelyLookingWoman do
  @moduledoc """
  Brenda Howard shares news of her family and receives her husband's letter.

  ## Behavior

  - Identifies her husband by name and directs visitors to her daughter.
  - Accepts his letter and advances the quest, with dialogue changing as it progresses.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen_in",
        x: 159,
        y: 48,
        dir: 5,
        sprite: 711,
        name: "Lonely-looking Woman",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Brenda Howard]")
    progress = get_char_var(ctx, :sign_q, 0)

    cond do
      progress < 54 ->
        ctx
        |> mes("Hmm...")
        |> mes("What should I make for")
        |> mes("dinner today? Pickled cabbage?")
        |> mes(
          "I learned how to make it a while ago, but I've never gotten the chance to make it yet..."
        )
        |> close()

      progress == 54 ->
        ask_husband(ctx)

      progress < 57 ->
        ctx
        |> mes("Ho-ho~!")
        |> mes("Crisp and delicious pickled")
        |> mes(
          "cabbage~ My kid loves this stuff and finished it all by herself the last time I made it."
        )
        |> close()

      progress == 57 ->
        ctx
        |> mes("Ah...")
        |> mes("So you've seen my husband.")
        |> mes("How is he doing? I worry about")
        |> mes("whether or not he's taking care")
        |> mes("of himself enough...")
        |> next()
        |> mes("[Brenda Howard]")
        |> mes("Oh, I can't help but worry!")
        |> mes("Thank you for letting me know")
        |> mes("how he's doing. Still, he should")
        |> mes("be doing a better job of keeping")
        |> mes("in touch with us. ^333333*Sigh*^000000")
        |> emotion(:think)
        |> close()

      progress < 62 ->
        receive_letter(ctx)

      progress < 67 ->
        ctx
        |> mes("So how have you been?")
        |> mes("So how have you been?")
        |> mes("As usual, Liana misses")
        |> mes("her daddy, but I suppose")
        |> mes("it can't be helped...")
        |> next()
        |> mes("I may be no expert, but I'm")
        |> mes("certain that my husband is")
        |> mes(
          "the best blacksmith in the world! Did you know Hollgrehenn and Aragham used to be his apprentices? Ho ho ho~"
        )
        |> close()

      true ->
        ctx
        |> mes("Try to cherish your")
        |> mes("family, especially through the")
        |> mes(
          "hard times. Even when you're angry with them, try to be more understanding. I know it's hard..."
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ask_husband(ctx) do
    ctx =
      ctx
      |> mes("Hey, who are you anyhow?")
      |> mes("Don't you know it's rude to")
      |> mes("enter someone's house without")
      |> mes(
        "being invited? Besides, I don't have the time to help strangers while I'm busy making dinner..."
      )
      |> next()

    {ctx, name} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("W-wait!")
      |> mes("I'm here to see...")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", name)

    if get_local(ctx, :"input$", "") != "Engel Howard" do
      ctx
      |> mes("[Brenda Howard]")
      |> mes("Huh?")
      |> mes("What are you")
      |> mes("talking about?")
      |> next()
      |> mes("[Brenda Howard]")
      |> mes("Hmm...")
      |> mes("I wonder")
      |> mes("how my pickled")
      |> mes("cabbage will turn out?")
      |> emotion(:delight)
      |> close()
    else
      ctx
      |> mes("[Brenda Howard]")
      |> mes("Ah... I see.")
      |> mes("You're looking for my husband.")
      |> mes("My husband, my daughter and")
      |> mes("I just moved to Geffen from")
      |> mes("Prontera a while ago.")
      |> next()
      |> mes("[Brenda Howard]")
      |> mes(
        "We moved to Geffen for the sake of my husband's business. Apparently, this town is closest to something he really seems to need. Whatever it is, it must be really important to his smithing work."
      )
      |> next()
      |> mes("[Brenda Howard]")
      |> mes("Oh, and if you're going to look")
      |> mes(
        "for my husband, please talk to my daughter before you go. I think she has something that she wants to give to her father..."
      )
      |> set_char_var(:sign_q, 55)
      |> close()
    end
  end

  defp receive_letter(ctx) do
    if count_item(ctx, 7278) > 0 do
      ctx =
        ctx
        |> mes("Thank you so much for bringing")
        |> mes("this to me. I'm so happy to hear that he's fine and doing well.")
        |> mes("Although he's not here often enough, it's good to know")
        |> mes("that he loves his job.")
        |> next()
        |> mes("[Brenda Howard]")
        |> mes("Even so, I should start letting")
        |> mes("him know that I want him to spend")
        |> mes(
          "a little more time at home. Oh, and why don't you talk to Liana? She's been waiting to tell you something."
        )
        |> delitem(7278, 1)

      ctx
      |> set_char_var(:sign_q, get_char_var(ctx, :sign_q, 0) + 4)
      |> close()
    else
      ctx
      |> mes(
        "Liana's daddy needs to come home more often. ^333333*Sigh*^000000 Even though he's away for long periods of time, I suppose it's for the best..."
      )
      |> close2()
      |> emotion(:think)
    end
  end
end
