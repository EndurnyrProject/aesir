defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Valkyrie do
  @moduledoc """
  A Valkyrie guides Lowen and the player at the end of their journey.

  ## Behavior

  - Promotes Lowen, reveals clues and returns the player to Geffen.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
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
        map: "que_god02",
        x: 178,
        y: 127,
        dir: 3,
        sprite: 811,
        name: "Valkyrie",
        scope: :shared,
        unique_name: "Valkyrie#1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :god_brising, 0) == 31 do
      invitation(ctx)
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp invitation(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Valkyrie]")
      |> mes("You have passed")
      |> mes("the test, Lowen.")
      |> mes("I don't have much")
      |> mes("time to speak.")
      |> next()
      |> mes("[Valkyrie]")
      |> mes(
        "Have you found the strength to release yourself from the guilt and the pain? I have been waiting for you. Will you accept my invitation to Valhalla?"
      )
      |> next()
      |> select(["Yes, I will follow you.", "Um... I'm not Lowen."])

    case answer do
      1 -> ctx |> accept_invitation() |> reveal_clues(true)
      2 -> ctx |> explain_identity() |> reveal_clues(false)
      _ -> ctx
    end
  end

  defp accept_invitation(ctx) do
    ctx
    |> mes("[Valkyrie]")
    |> mes("Lowen Ellenen, misunderstood hero. I will now promote you")
    |> mes("to Einherjar with")
    |> mes("the will of God.")
    |> next()
    |> mes("[Valkyrie]")
    |> mes(
      "Your soul and spirit will be reborn in Valhalla as a holy warrior preparing for the holy war."
    )
    |> specialeffect2(:blessing)
    |> next()
    |> mes("[Valkyrie]")
    |> mes("And...")
  end

  defp explain_identity(ctx) do
    ctx =
      ctx
      |> mes("[Valkyrie]")
      |> mes("Hahahaha...")
      |> mes("It has been")
      |> mes("a while since")
      |> mes("a mortal has")
      |> mes("made me laugh.")
      |> next()
      |> mes("[Valkyrie]")

    ctx
    |> mes("#{char_name(ctx, 0)},")
    |> mes("I am speaking to the")
    |> mes(
      "spirit that rests within you, the girl to whom you lent your body so that she may learn the truth of the past."
    )
    |> next()
    |> mes("[Valkyrie]")
    |> mes("Lowen Ellenen,")
    |> mes("misunderstood hero.")
    |> mes("I will now promote you to Einherjar with the will of God.")
    |> next()
    |> mes("[Valkyrie]")
    |> mes("Your soul and")
    |> mes("spirit will be reborn in Valhalla as a holy warrior preparing for the holy war.")
    |> specialeffect2(:blessing)
    |> next()
    |> mes("[Valkyrie]")
    |> mes("And...")
  end

  defp reveal_clues(ctx, mention_dwarves?) do
    ctx =
      ctx
      |> mes("#{char_name(ctx, 0)},")
      |> mes("Your exploits are known to me. But I am curious as to what has brought you here?")
      |> next()
      |> mes(
        "^3355FFYou explained what happened to the Valkyrie, starting from the Snow Crystal which never melts.^000000"
      )
      |> next()
      |> mes("[Valkyrie]")
      |> mes("I understand.")
      |> mes(
        "The story begins a long, long time ago with Freya, the patron goddess of beauty and love."
      )
      |> next()
      |> mes("[Valkyrie]")
      |> mes(
        "Her teardrop became a beautiful jewel. The snow on which Freya's teardrops have fallen will always retain its crystalline beauty."
      )
      |> next()
      |> mes("[Valkyrie]")
      |> mes(
        "You seek traces of the goddess? Perhaps this is a sign of the end of the thousand year peace. When the time comes, I hope humans will not abandon their faith."
      )
      |> next()
      |> mes("[Valkyrie]")
      |> mes(
        "Perhaps, I was also sent to meet you. I wish that humans will use the power derived from the traces of the gods to protect justice."
      )
      |> next()
      |> mes("[Valkyrie]")

    ctx =
      ctx
      |> mes("#{char_name(ctx, 0)}...")
      |> mes("Listen. This is")
      |> mes("what you must find.")
      |> next()
      |> mes("[Valkyrie]")
      |> mes("A cold snowy path on")
      |> mes("which the goddess tread.")
      |> mes("A blue river the goddess crossed.")
      |> mes("A narrow path the goddess passed.")

    ctx = if mention_dwarves?, do: mes(ctx, "Four dwarves that the goddess met..."), else: ctx

    ctx
    |> next()
    |> mes("[Valkyrie]")
    |> mes("^4d4dffThe beauty of the stars")
    |> mes("Wanes in comparison.")
    |> mes("We lost our hearts")
    |> mes("To that golden hair")
    |> mes("And those dazzling eyes.^000000")
    |> next()
    |> mes("[Valkyrie]")
    |> mes("Remember this.")
    |> mes("I shall send you")
    |> mes("back to where you")
    |> mes("belong.")
    |> set_char_var(:god_brising, 34)
    |> next()
    |> mes("[Valkyrie]")
    |> mes("For Odin's honor...")
    |> close2()
    |> hideonnpc("#doppelganger1")
    |> hideonnpc("#doppelganger2")
    |> hideonnpc("#knight1")
    |> hideonnpc("#knight2")
    |> hideonnpc("#knight3")
    |> hideonnpc("#lowen")
    |> hideoffnpc("Soldier#1_brising")
    |> hideonnpc("Soldier#2_brising")
    |> hideoffnpc("#hermite")
    |> hideoffnpc("Lowen Ellenen#2")
    |> hideonnpc("Valkyrie#1")
    |> warp("geffen", 120, 101)
  end
end
