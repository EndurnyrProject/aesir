defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsHugel.SuspiciousBarrel do
  @moduledoc """
  A suspicious barrel hides Torpy's hungry father.

  ## Behavior

  - Requests a meal and advances the Hide and Seek Quest when it is delivered.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "hugel",
        x: 100,
        y: 176,
        dir: 3,
        sprite: 111,
        name: "Suspicious Barrel",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @steamed_crab_nippers 12051

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :hg_ubu01, 0) do
      3 ->
        request_meal(ctx)

      stage when stage in [4, 5] ->
        deliver_meal(ctx)

      6 ->
        ctx
        |> emotion(:think, playerattached(ctx))
        |> mes("^3355FFFor now, you should")
        |> mes("tell Torpy and his mom")
        |> mes("where Torpy's father is")
        |> mes("hiding so they won't")
        |> mes("worry about him so much.")
        |> close()

      7 ->
        ctx
        |> emotion(:think, playerattached(ctx))
        |> mes("^800080Torpy's mom might want to know about^000000")
        |> mes("^800080this extraordinary barrel.^000000")
        |> close()

      8 ->
        ctx
        |> emotion(:think, playerattached(ctx))
        |> mes("^800080How long does Torpy's father plan to stay within the barrel?^000000")
        |> close()

      9 ->
        ctx
        |> emotion(:think, playerattached(ctx))
        |> mes("^800080That barrel will become a symbolic object^000000")
        |> mes("^800080that pays tribute to the firm will of Torpy's father^000000")
        |> mes(
          "^800080who is trying hard to avoid keeping the promise with his son to find his wife.^000000"
        )
        |> close()

      _ ->
        ctx
        |> emotion(:think, playerattached(ctx))
        |> mes("^800080You hear something bustling from the hole in the barrel.^000000")
        |> mes("^800080However, it doesn't seem to be a big deal.^000000")
        |> close()
    end
  end

  defp request_meal(ctx) do
    ctx =
      ctx
      |> mes("[Strange Man]")
      |> mes("So... hun...gry...")
      |> mes("F-food... Give me...")
      |> mes("F-food... Must... replenish...")
      |> mes("h-health... with... Steamed...")
      |> mes("Crab... Nippers... Please...")
      |> next()

    {ctx, choice} =
      ctx
      |> emotion(:think, playerattached(ctx))
      |> mes("^3355FFIt sounds like")
      |> mes("this barrel wants")
      |> mes("Steamed Crab Nippers.^000000")
      |> next()
      |> select(["I'll bring you Steamed Crab Nippers", "Ignore"])

    case choice do
      1 ->
        ctx =
          ctx
          |> mes("[Strange Man]")
          |> mes("Please... cook me...")
          |> mes("Steamed... Crab Nippers...!")
          |> mes("You... n-need.... 10 Green")
          |> mes("Herbs... 1 Yellow Potions...")
          |> mes("and 10... N-Nippers... to")
          |> mes("c-cook th-them. Ugh...")
          |> next()

        ctx = emotion(ctx, :think, playerattached(ctx))

        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Hold on,")
        |> mes("I have to cook")
        |> mes("them for you?!")
        |> next()
        |> mes("[Strange Man]")
        |> mes("Y-yes...")
        |> mes("It's... It's the")
        |> mes("o-only... possible...")
        |> mes("Way... P-please help...")
        |> set_char_var(:hg_ubu01, 4)
        |> changequest(12046, 12047)
        |> close()

      2 ->
        ctx =
          ctx
          |> mes("[Strange Man]")
          |> mes("D-don't... leave...")
          |> mes("me... Here... Th-the...")
          |> mes("hunger...! It... It can't...")
          |> mes("It c-can't be... d-denied!")
          |> next()

        ctx = emotion(ctx, :think, playerattached(ctx))

        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Weirdo! Why don't you")
        |> mes("get out of that barrel,")
        |> mes("and get your Steamed")
        |> mes("Crab Nippers yourself?!")
        |> close()

      _ ->
        ctx
    end
  end

  defp deliver_meal(ctx) do
    if Rathena.truthy?(count_item(ctx, @steamed_crab_nippers)) do
      ctx =
        ctx
        |> mes("[Strange Man]")
        |> mes("Th-that... tantalizing...")
        |> mes("scent... It's S-Steamed...")
        |> mes("Crab... Nippers... Oh God...")
        |> mes("It's b-been so... l-long...")
        |> mes("G-Give me! G-Give me now!")
        |> next()

      ctx
      |> emotion(:think, playerattached(ctx))
      |> mes("^3355FFYou dumped the")
      |> mes("Steamed Crab Nippers")
      |> mes("into the barrel where")
      |> mes("it was quickly devoured.^000000")
      |> delitem(@steamed_crab_nippers, 1)
      |> set_char_var(:hg_ubu01, 5)
      |> next()
      |> mes("[Strange Man]")
      |> mes("Ha ha ha!")
      |> mes("Back in the game, baby!")
      |> mes("Man, it's been, about what,")
      |> mes("3 days since I last ate?")
      |> mes("It's good to be alive!")
      |> close()
      |> donpcevent("Strange Man#Hugel::OnEnable")
    else
      ctx =
        ctx
        |> mes("[Strange Man]")
        |> mes("Please... cook me...")
        |> mes("Steamed... Crab Nippers...!")
        |> mes("You... n-need.... 10 Green")
        |> mes("Herbs... 1 Yellow Potions...")
        |> mes("and 10... N-Nippers... to")
        |> mes("c-cook th-them. Ugh...")
        |> next()

      ctx = emotion(ctx, :think, playerattached(ctx))

      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Hold on,")
      |> mes("I have to cook")
      |> mes("them for you?!")
      |> next()
      |> mes("[Strange Man]")
      |> mes("Y-yes...")
      |> mes("It's... It's the")
      |> mes("o-only... possible...")
      |> mes("Way... P-please help...")
      |> close()
    end
  end
end
