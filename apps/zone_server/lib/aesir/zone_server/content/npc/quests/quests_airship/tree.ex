defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.Tree do
  @moduledoc """
  The trees conceal a journal for the airship ticket quest.

  ## Behavior

  - A search may reveal Kain’s buried journal, which can then be reread.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
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
        map: "einbech",
        x: 45,
        y: 113,
        dir: 5,
        sprite: 111,
        name: "Tree",
        scope: :shared,
        hidden_name: "t1-1"
      },
      %{
        map: "einbech",
        x: 36,
        y: 100,
        dir: 5,
        sprite: 111,
        name: "Tree",
        scope: :shared,
        unique_name: "Tree#t1-2"
      },
      %{
        map: "einbech",
        x: 44,
        y: 90,
        dir: 5,
        sprite: 111,
        name: "Tree",
        scope: :shared,
        unique_name: "Tree#t1-3"
      },
      %{
        map: "einbech",
        x: 53,
        y: 94,
        dir: 5,
        sprite: 111,
        name: "Tree",
        scope: :shared,
        unique_name: "Tree#t1-4"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :kain_ticket, 0) do
      11 ->
        search_for_journal(ctx)

      12 ->
        ctx
        |> mes("^3355FFYou open")
        |> mes("the journal")
        |> mes("and begin to read...^000000")
        |> read_journal()
        |> close()

      _ ->
        ctx
    end
  end

  defp search_for_journal(ctx) do
    ctx =
      ctx
      |> mes("^3355FFYou crouch down")
      |> mes("under the tree and")
      |> mes("begin digging into")
      |> mes("the ground.^000000")
      |> next()
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> set_local(:find_diary, Enum.random(1..100))

    if get_local(ctx, :find_diary, 0) > 10 do
      ctx
      |> mes("^3355ffUnfortunately,")
      |> mes("you weren't able")
      |> mes("to find anything.^000000")
      |> close()
    else
      ctx
      |> mes("^3355FFYou have found a journal")
      |> mes("among some other articles")
      |> mes("that have been buried by Kain.")
      |> mes("You open the journal and begin")
      |> mes("to read what's written inside.^000000")
      |> read_journal()
      |> next()
      |> mes("...")
      |> mes("......")
      |> next()
      |> mes(
        "^3355FFThat was the last page of the journal. You picked it up so that you can bring it over to ^3131FFTarsha.^000000"
      )
      |> changequest(2082, 2083)
      |> set_char_var(:kain_ticket, 12)
      |> close()
    end
  end

  defp read_journal(ctx) do
    ctx
    |> next()
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("<Date : OX OX>")
    |> mes("^856363I'm sooo happy")
    |> mes("to be with Kain.")
    |> mes("He's such an honest,")
    |> mes("sincere man, even if")
    |> mes("he is quiet sometimes.")
    |> next()
    |> mes("^856363Although he's a very")
    |> mes("good husband to me,")
    |> mes("I'm not so good at being")
    |> mes("a housewife. But I'll do")
    |> mes("my very best for us both.")
    |> next()
    |> mes("<Date : OX OX>")
    |> mes("^856363I fell asleep while")
    |> mes("fixing dinner and burned")
    |> mes("all the food. How can I be")
    |> mes("so careless? But Kain ate")
    |> mes("every bite, even if he had")
    |> mes("to pretend that he liked it.^000000")
    |> next()
    |> mes("<Date : OX OX>")
    |> mes("^856363Kain and I will be having")
    |> mes("a child soon! I'm so happy,")
    |> mes("but I'm also a little worried")
    |> mes("sometimes. Kain is all smiles")
    |> mes("though, and he gives me relief.^000000")
    |> next()
    |> mes("<Date : OX OX>")
    |> mes("^856363More people have been")
    |> mes("leaving the mines to work")
    |> mes("for the new factories, many")
    |> mes("of them Kain's friends. I think")
    |> mes("Kain's pride was pretty hurt.")
    |> mes("I wonder how I can help him?^000000")
    |> next()
    |> mes("<Date : OX OX>")
    |> mes("^856363Kain and I are now the")
    |> mes("proud parents of a beautiful")
    |> mes("baby girl. We named her ^000000Tarsha^856363")
    |> mes("and she has her father's eyes.")
    |> mes("I'm going to be the best mother")
    |> mes("that I can possibly be for her.")
    |> next()
    |> mes("<Date : OX OX>")
    |> mes("^856363Tarsha called me")
    |> mes("''Mommy'' for the first")
    |> mes("time! It's a miracle!")
    |> mes("I want nothing else in")
    |> mes("the world but for her to")
    |> mes("be happy and healthy.^000000")
    |> next()
    |> mes("<Date : OX OX>")
    |> mes("^856363Kain got into an accident")
    |> mes("at the mine. While they were")
    |> mes("digging ores, toxic gas was")
    |> mes("released somehow. It wasn't")
    |> mes("lethal, but Kain's arm has")
    |> mes("been partly paralyzed...^000000")
    |> next()
    |> mes("^856363When the doctor said that")
    |> mes("it may even affect his memories")
    |> mes("later, he became so depressed.")
    |> mes("I tried to make him feel better")
    |> mes("by making his favorite soup.")
    |> mes("He smiled, but I could tell...^000000")
    |> next()
    |> mes("^856363I could tell he's")
    |> mes("not alright with this.")
    |> mes("I hope he feels better")
    |> mes("soon. His despair is")
    |> mes("at least as great as his")
    |> mes("passion for his job.^000000")
    |> next()
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("<Date : OX OX>")
    |> mes("^856363Kain's drinking is")
    |> mes("getting worse. He comes")
    |> mes("home too often screaming")
    |> mes("and yelling. There's too")
    |> mes("much anger in him and he's")
    |> mes("not the same anymore...")
    |> next()
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("<Date : OX OX>")
    |> mes("^856363Tarsha got her hand")
    |> mes("scalded from boiling")
    |> mes("water while playing in")
    |> mes("the kitchen. Although she")
    |> mes("was treated, she'll always")
    |> mes("have that ^000000burn mark^856363.^000000")
    |> next()
    |> mes("^856363After we got home from")
    |> mes("the doctor's, Tarsha laughed")
    |> mes("and played with her doll as if")
    |> mes("nothing ever happened. But for")
    |> mes("some reason, I couldn't stop")
    |> mes("myself from crying...^000000")
    |> next()
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("<Date : OX OX>")
    |> mes("^856363Kain comes home less")
    |> mes("nowadays. I've had to")
    |> mes("start working in the store")
    |> mes("after we spent all of our")
    |> mes("savings. It's tough working")
    |> mes("and taking care of the family.")
    |> next()
    |> mes("^856363Still, it's all worth")
    |> mes("it to see Tarsha's smile.")
    |> mes("But I can never stop worrying")
    |> mes("about my poor, dear Kain...")
    |> next()
    |> mes("...")
    |> mes("......")
    |> next()
    |> mes("<Date : OX OX>")
    |> mes("^856363Everyday, I feel weaker")
    |> mes("and weaker, as if I die")
    |> mes("just a little more each day.")
    |> mes("I wanted to tell Kain about")
    |> mes("what the doctor said, but he's")
    |> mes("not ready for this news yet...^000000")
    |> next()
    |> mes("^856363Lately, Tarsha cries")
    |> mes("a lot. My poor baby loves")
    |> mes("her father, but he's always")
    |> mes("so distant. But sometimes,")
    |> mes("I see him sadly smile for")
    |> mes("Tarsha, if only for a moment.^000000")
  end
end
