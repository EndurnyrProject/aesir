defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.ReceptionistBrink do
  @moduledoc """
  Brink, the stammering registration clerk of the Ash-Vacuum expedition office.

  ## Behavior

  - Before step 3 Brink can barely get a sentence out.
  - On step 3 offers a two-option menu: registering plays the whole stammering form, sets
    `ep13_newbs` to 4, hands over a Chocolate Pie and advances quest 11085 to 11086, while
    "just stand" only gets one more stammer.
  - From step 4 on he greets the player as an existing member.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mid_campin",
        x: 106,
        y: 122,
        dir: 4,
        sprite: 89,
        name: "Receptionist Brink",
        scope: :shared,
        unique_name: "Receptionist Brink#ep13b"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @gift 12322

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_newbs, 0) do
      step when step < 3 -> too_nervous(ctx)
      3 -> registration_menu(ctx)
      _step -> already_a_member(ctx)
    end
  end

  defp too_nervous(ctx) do
    ctx
    |> mes("[Brink]")
    |> mes("Hmm... Hey...")
    |> mes("...I mean...")
    |> mes("Hmm...")
    |> mes("...I would...")
    |> emotion(:profusely_sweat)
    |> close()
  end

  defp registration_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Brink]")
      |> mes("Hmm... Hey...")
      |> mes("...What makes...")
      |> mes("Hmm...")
      |> mes("...I would...")
      |> emotion(:profusely_sweat)
      |> next()
      |> mes("[Brink]")
      |> mes("Hmmm... Hey...")
      |> mes("...register...")
      |> mes("I mean...")
      |> next()
      |> select(["I am here to register.", "Just stand."])

    case choice do
      1 -> register(ctx)
      2 -> nothing_then(ctx)
      _ -> ctx
    end
  end

  defp register(ctx) do
    ctx =
      ctx
      |> mes("[Brink]")
      |> mes("Ah... I mean...")
      |> mes("Hmm...")
      |> mes("...Hey...")
      |> mes("What...your name...")
      |> emotion(:profusely_sweat)
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")

    ctx =
      ctx
      |> mes("My name is #{char_name(ctx, 0)}.")
      |> next()
      |> mes("[Brink]")
      |> mes("...Ah...")

    ctx =
      ctx
      |> mes("#{char_name(ctx, 0)}...")
      |> mes("You...")
      |> mes("...registered...Hmm...")
      |> mes("...")
      |> emotion(:profusely_sweat)
      |> next()

    ctx
    |> mes("[Brink]")
    |> mes("Here...")
    |> mes("Hmm...")
    |> mes("sign...")
    |> next()
    |> mes("[Brink]")
    |> mes("Hmmm...")
    |> mes("and...")
    |> mes("I mean...")
    |> emotion(:profusely_sweat)
    |> next()
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Is it finished?")
    |> next()
    |> mes("[Brink]")
    |> mes("Hm...")
    |> mes("...Yes...")
    |> mes("Then...")
    |> next()
    |> mes("[Brink]")
    |> mes("And...")
    |> mes("......This thing...")
    |> mes("...Ehh...")
    |> next()
    |> mes("- I guess I'm registered -")
    |> mes("- I'd better go back to Lugen -")
    |> set_char_var(:ep13_newbs, 4)
    |> give_item(@gift, 1)
    |> changequest(11085, 11086)
    |> close()
  end

  defp nothing_then(ctx) do
    ctx
    |> mes("[Brink]")
    |> mes("And...")
    |> mes("......This thing...")
    |> mes("...Ehh...")
    |> emotion(:profusely_sweat)
    |> close()
  end

  defp already_a_member(ctx) do
    ctx
    |> mes("[Brink]")
    |> mes("...Hey...")
    |> mes("I mean...")
    |> mes("...Well...nice...")
    |> mes("Then...")
    |> next()
    |> mes("[Brink]")
    |> mes("...Life...")
    |> mes("...Hmmm...")
    |> close()
  end
end
