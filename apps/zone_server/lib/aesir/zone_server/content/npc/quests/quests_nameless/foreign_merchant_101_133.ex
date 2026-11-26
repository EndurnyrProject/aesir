defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.ForeignMerchant101133 do
  @moduledoc """
  A foreign merchant shares his fruit wine during an errand.

  ## Behavior

  - Advances the wine errand and hides after giving away his last bottle.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_ruins",
        x: 101,
        y: 133,
        dir: 7,
        sprite: 929,
        name: "Foreign Merchant",
        scope: :shared,
        unique_name: "Foreign Merchant#aru2"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :aru_em, 0) > 1 and get_char_var(ctx, :aru_em, 0) < 7 do
      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Excuse me, but I heard")
        |> mes("that I could buy some")
        |> mes("good drinks around here.")
        |> mes("Would you happen to be")
        |> mes("the one selling them?")
        |> next()
        |> mes("[Foreign Merchant]")
        |> mes("Oh, you mean my fruit wine?")
        |> mes("I'm afraid it's not as good")
        |> mes("as people chalk it up to be.")
        |> mes("It's just a little something")
        |> mes("I brew at home, and share")
        |> mes("with my friends after dinner.")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Well, I ran into this")
        |> mes("merchant that really wants")
        |> mes("to have a taste of that wine.")
        |> mes("Do you think that you'd be")
        |> mes("able to sell me some?")
        |> next()
        |> mes("[Foreign Merchant]")
        |> mes("Oh, I'm sorry, but I'm")
        |> mes("all sold out for today.")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Oh, no...")

      ctx =
        ctx
        |> emotion(:otl, playerattached(ctx))
        |> next()
        |> mes("[Foreign Merchant]")
        |> mes("...............................")
        |> mes("...............................")
        |> mes("...............................")
        |> emotion(:profusely_sweat)
        |> next()

      ctx =
        ctx
        |> emotion(:huk, playerattached(ctx))
        |> mes("[Foreign Merchant]")
        |> mes("You know, I save a small")
        |> mes("bottle of wine for myself")
        |> mes("so I'll just give that to you.")
        |> mes("I can always brew more, and")
        |> mes("I'm flattered that your friend")
        |> mes("is so interested in my wine.")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Really? Thank you!")
      |> mes("I'm sure that he's really")
      |> mes("appreciate your generosity.")
      |> next()
      |> mes("[Foreign Merchant]")
      |> mes("Oh, don't mention it.")
      |> mes("Well, I should head back")
      |> mes("home now. I'll be sure to")
      |> mes("keep an extra bottle in case")
      |> mes("you want more next time. Take")
      |> mes("care, and I'll see you later!")
      |> emotion(:flag)
      |> next()
      |> mes("^3355FFYou received a bottle")
      |> mes("of the famous fruit wine")
      |> mes("from the old man. That")
      |> mes("guy's pretty nice!^000000")
      |> set_char_var(:aru_em, 7)
      |> hideonnpc("Foreign Merchant#aru2")
      |> changequest(2129, 2130)
      |> close()
    else
      ctx
      |> mes("[Foreign Merchant]")
      |> mes("I'm sorry, but I'm all")
      |> mes("sold out of fruit wine.")
      |> mes("I hope that's not too")
      |> mes("much of an inconvenience.")
      |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_oninit(ctx) do
    hideonnpc(ctx, "Foreign Merchant#aru2")
  end
end
