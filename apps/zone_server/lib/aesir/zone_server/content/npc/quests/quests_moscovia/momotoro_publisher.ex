defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.MomotoroPublisher do
  @moduledoc """
  A publisher selling books ordered by Baba Yaga.

  ## Behavior

  - Sells the ordered books when the correct name and enough Zeny are provided.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "amatsu",
        x: 233,
        y: 234,
        dir: 3,
        sprite: 758,
        name: "Momotoro Publisher",
        scope: :shared,
        unique_name: "Momotoro Publisher#rus42"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 3500 ->
        ctx
        |> mes("[Momotoro Publisher]")
        |> mes("What on earth do you have in your bag?")
        |> mes("Are you training for something?")
        |> close()

      get_char_var(ctx, :rhea_rus_main, 0) < 26 ->
        greeting(ctx)

      get_char_var(ctx, :rhea_rus_main, 0) == 26 ->
        buy_books(ctx)

      get_char_var(ctx, :rhea_rus_main, 0) > 26 and
          get_char_var(ctx, :rhea_rus_main, 0) < 31 ->
        thank_customer(ctx)

      true ->
        greeting(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Momotoro Publisher]")
    |> mes("Did you order a book?")
    |> next()
    |> mes("[Momotoro Publisher]")
    |> mes("Someone ordered a book but did not pick it up.")
    |> close()
  end

  defp buy_books(ctx) do
    ctx =
      ctx
      |> mes("[Momotoro Publisher]")
      |> mes("Did you order a book?")
      |> next()
      |> mes("[Momotoro Publisher]")
      |> mes("Someone ordered a book but did not pick it up.")
      |> next()

    {ctx, name} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Ah, I.. a magic book...")
      |> next()
      |> mes("[Momotoro Publisher]")
      |> mes("What? Ah, did you come here to pick up the book? Please, let me know your name?")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", name)

    if get_local(ctx, :"input$", "") == "Baba Yaga" do
      ctx = mes(ctx, Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("I am ", get_local(ctx, :"input$", "")), "."))
        |> next()
        |> mes("[Momotoro Publisher]")
        |> mes(
          Rathena.concat(
            Rathena.concat("", get_local(ctx, :"input$", "")),
            " ... Ah, here it is."
          )
        )
        |> next()
        |> mes("[Momotoro Publisher]")
        |> mes(
          "Are these the right ones? 'Magic to destroy time', 'The story of the house ghost around the world', 'Strange and weird world of Herbs"
        )
        |> mes("Hmm, the price for all is 5,000 Zeny.")
        |> next()

      if zeny(ctx) > 4999 do
        ctx
        |> mes("[Momotoro Publisher]")
        |> mes("Eh, yep this is 5,000 Zeny.")
        |> next()
        |> mes("[Momotoro Publisher]")
        |> mes("Thank you for buying our books. If you need more books, contact us please.")
        |> give_item(7881, 1)
        |> pay_zeny(5000)
        |> set_char_var(:rhea_rus_main, 27)
        |> close()
      else
        ctx
        |> mes("[Momotoro Publisher]")
        |> mes("You don't have enough money?")
        |> mes("Check it again and come to me, please")
        |> close()
      end
    else
      ctx = mes(ctx, Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))

      ctx
      |> mes(Rathena.concat(Rathena.concat("I am ", get_local(ctx, :"input$", "")), " "))
      |> next()
      |> mes("[Momotoro Publisher]")
      |> mes(
        Rathena.concat(Rathena.concat("", get_local(ctx, :"input$", "")), " ... Let's see...")
      )
      |> next()
      |> mes("[Momotoro Publisher]")
      |> mes(
        Rathena.concat(
          Rathena.concat(
            "Hmm? I am sorry but there is no book reserved for ",
            get_local(ctx, :"input$", "")
          ),
          ". Can you check again please?"
        )
      )
      |> close()
    end
  end

  defp thank_customer(ctx) do
    ctx
    |> mes("[Momotoro Publisher]")
    |> mes("Thank you for buying our books. If you need more books, contact us please.")
    |> close()
  end
end
