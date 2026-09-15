defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.Assassin do
  @moduledoc """
  Explains the Assassin’s Katar and dual-dagger fighting styles.

  ## Behavior

  - Offers detailed information about Katars or dual daggers.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_fild16",
        x: 211,
        y: 254,
        dir: 4,
        sprite: 118,
        name: "Assassin",
        scope: :shared,
        unique_name: "Assassin#07rhea_30"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[La Conte]")
      |> mes("Once Thiefs are promoted")
      |> mes("to Assassins, which is very professional")
      |> mes("they will be able to vary their battle style.")
      |> mes("their battle style.")
      |> mes("There are 2 main battle styles available to Assassins.")
      |> mes("They may either wield dual daggers,")
      |> mes("or fight with a set of Katars!")
      |> next()
      |> select(["Specialty of Katar", "Specialty of Dual Daggers", "Quit Conversation"])

    case choice do
      1 ->
        ctx
        |> mes("[La Conte]")
        |> mes("A set of Katars is")
        |> mes("worn on both of the hands,")
        |> mes("and allows Assassins")
        |> mes("to quickly slash their enemies.")
        |> mes("Anyone can buy a basic set of Katars")
        |> mes("in Morocc somewhere.")
        |> mes("Of course, only Assassins can use them.")
        |> next()
        |> mes("[La Conte]")
        |> mes("The right Katar")
        |> mes("usually does more damage,")
        |> mes("while the left Katar")
        |> mes("is used for the follow-through.")
        |> mes("But since Katars are equipped on both hands,")
        |> mes("you can't equip a shield or an extra weapon.")
        |> next()
        |> mes("[La Conte]")
        |> mes("Compared to Dual Daggers,")
        |> mes("Katars have faster attack speed.")
        |> mes("Also, the ^663399Sonic Blow^000000 skill")
        |> mes("can only be used with Katars.")
        |> next()
        |> mes("[La Conte]")
        |> mes("You can learn the Sonic Blow skill")
        |> mes("at ^663399Level 4 Katar Mastery^000000.")
        |> mes("If you're an Assassin,")
        |> mes("it's a handy skill to know.")
        |> next()
        |> mes("[La Conte]")
        |> mes("Sonic Blow is the skill")
        |> mes("that inflicts 8 continuous hits of")
        |> mes("Neutral damage.")
        |> close()

      2 ->
        ctx
        |> mes("[La Conte]")
        |> mes("Dual Daggers")
        |> mes("enables you to equip")
        |> mes("2 different kinds of Daggers")
        |> mes("at the same time.")
        |> mes("Of course,")
        |> mes("there are other weapons you can equip")
        |> mes("aside from daggers,")
        |> next()
        |> mes("[La Conte]")
        |> mes("but they'll probably")
        |> mes("be lacking in attack speed.")
        |> mes("So I suggest daggers.")
        |> mes("Also, without a dagger")
        |> mes("in your right hand,")
        |> mes(" you won't be able to use")
        |> mes("the ^663399Double Attack^000000 skill.")
        |> next()
        |> mes("[La Conte]")
        |> mes("So with Dual Daggers,")
        |> mes("you would have a double attack")
        |> mes("with the right hand dagger,")
        |> mes(" and a single attack with your left hand weapon.")
        |> next()
        |> mes("[La Conte]")
        |> mes("So that's three strikes")
        |> mes("in one blow!")
        |> mes("You can't argue")
        |> mes("against that kind of damage!")
        |> close()

      3 ->
        ctx
        |> mes("[La Conte]")
        |> mes("Hopefully")
        |> mes("you will make good use of")
        |> mes("the weapons at your disposal.")
        |> mes("Remember")
        |> mes("the importance of")
        |> mes("strategy and")
        |> mes("planning your attacks.")
        |> close()

      _ ->
        ctx
    end
  end
end
