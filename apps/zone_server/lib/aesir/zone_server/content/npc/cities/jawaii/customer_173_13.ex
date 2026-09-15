defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.Customer17313 do
  @moduledoc """
  Invites unmarried patrons of the Prontera pub into SoloHan's drinking challenge.

  ## Behavior

  - Treats unmarried patrons to repeated drinks and offers passage to Jawaii after enough rounds.
  - Rejects married patrons with gender-specific dialogue.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 173,
        y: 13,
        dir: 4,
        sprite: 86,
        name: "Customer",
        scope: :shared,
        unique_name: "Customer#SoloHan"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[SoloHan]")

    partner_id = getpartnerid(ctx)

    cond do
      not Rathena.truthy?(partner_id) -> invite_single_patron(ctx)
      Rathena.truthy?(partner_id) -> reject_married_patron(ctx)
      true -> confused_drunk(ctx)
    end
  end

  defp confused_drunk(ctx) do
    ctx
    |> mes("Oh man...")
    |> mes("I think I'm drunk~")
    |> mes("^666666*Hiccup!*^000000")
    |> next()
    |> mes("[SoloHan]")
    |> mes("What is that...?")
    |> mes("Is this the third time this week I've gotten plastered? Bachewcca, help me count!")
    |> close()
  end

  defp invite_single_patron(ctx) do
    ctx =
      ctx
      |> mes("Oh man...")
      |> mes("I think I'm drunk~")
      |> mes("^666666*Hiccup...!*^000000")
      |> next()
      |> mes("[SoloHan]")
      |> mes("Hey, you...!")
      |> mes("You understand, don't you?!")
      |> mes("Aren't you upset looking at all these happily married couples?!")
      |> mes("Yeah~? Me too!")
      |> next()
      |> mes("[SoloHan]")
      |> mes(
        "How dare they show off their happiness in front of people like us--!! ^666666*Sniff*^000000 Just because they found everlasting love, they think they're better than we are?!"
      )
      |> next()
      |> mes("[SoloHan]")
      |> mes(
        "I remember when couples were polite and were lovey dovey behind closed doors. Nowadays they hold hands, and even cuddle in public. I mean, come on! Get a room!"
      )
      |> next()
      |> mes("[SoloHan]")
      |> mes("I mean, ^666666*Sniff*^000000, it's not like,")
      |> mes("I'm lonely or anything. I don't neeeeeeeed a woman~!")
      |> mes("Right, Bachewcca!")
      |> next()
      |> mes("[Bachewcca]")
      |> mes("...!")
      |> emotion(:best)
      |> next()
      |> mes("[SoloHan]")
      |> mes("It's doesn't really matter whether you're married")
      |> mes("or not, right buddy? Right?!")
      |> mes("Come on! Drink with me!!")
      |> next()
      |> mes(
        "^3355FFSuddenly he treated me as a close friend. It's a little embarrassing, but it's not a bad idea to accept"
      )
      |> mes("a free drink...^000000")
      |> next()
      |> mes("^3355FF* Gulp Gulp Gulp *^000000")
      |> percent_heal(hp: -10, sp: 0)
      |> next()
      |> mes("[SoloHan]")
      |> mes("So, what do you say?")
      |> mes("Let's go somewhere")
      |> mes("with some real liquor.")

    case drinking_loop(ctx, 0) do
      {:warp, ctx} -> warp(ctx, "jawaii_in", 44, 124)
      {:stop, ctx} -> ctx
    end
  end

  defp reject_married_patron(ctx) do
    ctx =
      ctx
      |> mes("Oh man...")
      |> mes("I think I'm drunk~")
      |> mes("*Hiccup!*")
      |> next()
      |> mes("[SoloHan]")
      |> mes("...Wha!?")
      |> mes("Oh man!")
      |> mes("Get outta my face!")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        ctx |> mes("You smell like,") |> mes("whupped boyfriend") |> mes("or something!")
      else
        ctx
        |> next()
        |> mes("[SoloHan]")
        |> mes("I think I know a naggy wife")
        |> mes("when I see one! Go boss your")
        |> mes("hubby around or something!")
      end

    ctx
    |> next()
    |> mes("[SoloHan]")
    |> mes("Leave me alone!")
    |> mes(
      "I don't want any of your marital bliss to rub off on me. Come on, Bachewcca! Tell 'em their kind ain't welcome here!"
    )
    |> next()
    |> mes("[Bachewcca]")
    |> mes("^666666*Grrr...!*^000000")
    |> specialeffect(:throwitem)
    |> close()
  end

  defp drinking_loop(ctx, drink_level) do
    {ctx, choice} =
      ctx |> next() |> select(["...One more drink.", "...What kind of place is it?"])

    with {:continue, ctx, drink_level} <- maybe_have_another_drink(ctx, choice, drink_level),
         {:continue, ctx} <- maybe_offer_paradise(ctx, drink_level) do
      ctx
      |> have_challenge_drink()
      |> drinking_loop(drink_level + 3)
    end
  end

  defp maybe_have_another_drink(ctx, 1, drink_level) do
    ctx =
      ctx
      |> mes("[SoloHan]")
      |> mes("Yeah~!")
      |> mes("That's the spirit!")
      |> mes("Hey, Bachewcca...")
      |> mes("Let's drink!")
      |> next()
      |> mes("[Bachewcca]")
      |> mes("^666666*Grunt!*^000000")
      |> specialeffect(:talk_scream)
      |> next()
      |> mes("[SoloHan]")
      |> mes("To...")
      |> mes("To being single!")
      |> mes("F-Forever!!!")
      |> next()
      |> mes("^3355FF* Gulp Gulp Gulp *^000000")
      |> percent_heal(hp: -10, sp: 0)
      |> next()

    drink_level = drink_level + 2

    if drink_level > 8 do
      offer_paradise_after_warning(ctx)
    else
      {:continue, ctx, drink_level}
    end
  end

  defp maybe_have_another_drink(ctx, _choice, drink_level),
    do: {:continue, ctx, drink_level}

  defp offer_paradise_after_warning(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[SoloHan]")
      |> mes("Whoa...")
      |> mes("You alright?")
      |> mes("You seem kind of drunk...")
      |> next()
      |> mes("[SoloHan]")
      |> mes(
        "I guess now's the perfect time to have you sign this! Don't worry, I'll send you straight to paradise!"
      )
      |> next()
      |> select(["Sign", "Refuse to Sign"])

    if choice == 1 do
      ctx =
        ctx
        |> mes("[SoloHan]")
        |> mes("Alright!")
        |> mes("Take care!")
        |> mes("Hahaha!")
        |> close()
        |> percent_heal(hp: 100, sp: 0)

      {:warp, ctx}
    else
      ctx =
        ctx
        |> mes("[SoloHan]")
        |> mes("Oh...")
        |> mes("Man.")
        |> mes("So, you spoil parties")
        |> mes("like this all the time, eh?")
        |> close()

      {:stop, ctx}
    end
  end

  defp maybe_offer_paradise(ctx, drink_level) when drink_level > 6 do
    {ctx, choice} =
      ctx
      |> mes("[SoloHan]")
      |> mes("^666666*Hiccup!*^000000")
      |> mes("So you feel like having some")
      |> mes("real fun? Okay, then just sign over here. Count on me, I'll send you to paradise.")
      |> next()
      |> select(["Sign", "Refuse to Sign"])

    if choice == 1 do
      ctx =
        ctx
        |> mes("[SoloHan]")
        |> mes("Alright~!")
        |> mes("Take care and have fun!")
        |> mes("Harass some couples over there for me, will you?")
        |> close()
        |> percent_heal(hp: 100, sp: 0)

      {:warp, ctx}
    else
      ctx =
        ctx
        |> mes("[SoloHan]")
        |> mes("Oh...")
        |> mes("Man.")
        |> mes(
          "No wonder you're single. You can't even recognize a good time when it's right in front of you."
        )
        |> close()

      {:stop, ctx}
    end
  end

  defp maybe_offer_paradise(ctx, _drink_level), do: {:continue, ctx}

  defp have_challenge_drink(ctx) do
    ctx
    |> mes("[SoloHan]")
    |> mes("Drink, drink!")
    |> mes("That's not enough!")
    |> mes("Drink more, buddy!")
    |> next()
    |> mes("[SoloHan]")
    |> mes("To...")
    |> mes("To being single!")
    |> mes("FOR EVER.")
    |> next()
    |> mes("^3355FF*Gulp Gulp Gulp*^000000")
    |> percent_heal(hp: -10, sp: 0)
    |> next()
  end
end
