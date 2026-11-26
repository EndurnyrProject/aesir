defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsUmbala.UtanShaman do
  @moduledoc """
  An Umbala shaman creates elemental essences and dismantles elemental stones.

  ## Behavior

  - Requires the chief's permission before offering her services.
  - Creates essences from natural materials and dismantles stones into essences.

  ## Credits

  - Original from rAthena, authors and Contributors
    - sabernet09
    - rAthena Team
    - x[tsk]
    - Lupus
    - PoW
    - Evera
    - SinSloth
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Corrected `input_want` to the entered quantity in dismantling shortage messages.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "um_in", x: 44, y: 71, dir: 2, sprite: 782, name: "Utan Shaman", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if checkweight(ctx, [{908, 600}]) == 0 do
      carry_warning(ctx)
    else
      speak(ctx, get_char_var(ctx, :event_umbala, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp carry_warning(ctx) do
    ctx
    |> mes("^3355FFWait a second!")
    |> mes("Right now, you're carrying")
    |> mes("too many things with you.")
    |> mes("Please come back after")
    |> mes("using the Kafra Service")
    |> mes("to store some of your items.^000000")
    |> close()
  end

  defp speak(ctx, stage) do
    case stage do
      3 ->
        ctx
        |> mes("[Puchuchartan]")
        |> mes("I did not expect that even")
        |> mes("more of you Rune-Midgartsians")
        |> mes("would find my village. I am")
        |> mes("afraid that Mother Earth may")
        |> mes("be caused suffering because")
        |> mes("of this...")
        |> next()
        |> mes("[Puchuchartan]")
        |> mes("You Rune-Midgartsians are a very")
        |> mes("evil tribe...always accomplishing")
        |> mes("your goals whether the means are")
        |> mes("foul or fair, never hesitating to")
        |> mes("ruin the property of others to get")
        |> mes("what you want.")
        |> next()
        |> mes("[Puchuchartan]")
        |> mes("I am worried how continuing")
        |> mes("contact with the outside world")
        |> mes("will affect our future...")
        |> next()
        |> mes("[Puchuchartan]")
        |> mes("No one from Rune-Midgarts has ")
        |> mes("visited me without some purpose")
        |> mes("and I do not think that you")
        |> mes("are an exception.")
        |> next()
        |> mes("[Puchuchartan]")
        |> mes("I only use my power for the")
        |> mes("service of my tribe, and do not")
        |> mes("give my aid to strangers. If you")
        |> mes("really need my help, go ask for")
        |> mes("the chief's permission.")
        |> next()
        |> mes("[Puchuchartan]")
        |> mes("Also, I do not approve of")
        |> mes("outsiders talking to the tribe")
        |> mes("more than they have to...")
        |> mes("We want to live a peaceful life, so do not disturb us.")
        |> set_char_var(:event_umbala, 4)
        |> close()

      stage when stage in [4, 5] ->
        ctx
        |> mes("[Puchuchartan]")
        |> mes("I already told you to get the")
        |> mes("chief's approval. There is also")
        |> mes("the matter of my own business to take care of.")
        |> next()
        |> mes("[Puchuchartan]")
        |> mes("I know that you have gone through")
        |> mes("many difficulties to come here,")
        |> mes("but you have to leave now.")
        |> close()

      6 ->
        ctx
        |> mes("[Puchuchartan]")
        |> mes("I've heard from the chief that he")
        |> mes("has given you his approval...")
        |> mes("Although I do not like this, I")
        |> mes("will keep my promise. But it's")
        |> mes("your call if you really need my help or not.")
        |> next()
        |> mes("[Puchuchartan]")
        |> mes("My power allows me to create rough")
        |> mes("enchanted stones and to divide a")
        |> mes("pure enchanted stone into rough")
        |> mes("ones. So I may be able to help")
        |> mes("you in this way.")
        |> next()
        |> mes("[Puchuchartan]")
        |> mes("So come and speak to me when")
        |> mes("you think my power may be")
        |> mes("of service to you.")
        |> set_char_var(:event_umbala, 7)
        |> close()

      7 ->
        ctx
        |> mes("[Putsuchiritan]")
        |> mes("I don't know whether my talents")
        |> mes("will be useful to you, but I'll")
        |> mes("help you anyway.")
        |> next()
        |> mes("[Putsuchiritan]")
        |> mes("I can create elemental essence from natural objects,")
        |> mes("or, dismantle elemental stones into their component essences.")
        |> mes("Which would you like to do?")
        |> offer_services()

      _ ->
        ctx
        |> mes("[??????????]")
        |> mes("Umbah umbah umbabah Utan umbah")
        |> mes("Umbah mookala umbabah..")
        |> mes("Umbabahumbah umbabah")
        |> mes("Umbabah umbaba umbaumbah umbah")
        |> mes("Hum umbah umbah.")
        |> close2()
        |> warp("umbala", 217, 186)
    end
  end

  defp offer_services(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("[Puchuchartan]")
      |> mes("Rune-Midgartsian who has asked for")
      |> mes("my help...Although I am not sure")
      |> mes("if you really need my power, I")
      |> mes("will try to provide my assistance.")
      |> next()

    if checkweight(ctx, [{1101, 10}]) == 0 do
      belongings_warning(ctx)
    else
      choose_service(ctx)
    end
  end

  defp belongings_warning(ctx) do
    ctx
    |> mes("[Puchuchartan]")
    |> mes("Wait--!")
    |> mes("something in your possession")
    |> mes("is disturbing my peace of")
    |> mes("mind. This will not do...")
    |> next()
    |> mes("[Puchuchartan]")
    |> mes("Go leave your belongings")
    |> mes("elsewhere, and only bring the")
    |> mes("items that you need right now.")
    |> next()
    |> mes("[Puchuchartan]")
    |> mes("If you refuse to do so,")
    |> mes("I cannot do anything for you.")
    |> mes("Get yourself ready and then")
    |> mes("come back.")
    |> close()
  end

  defp choose_service(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Puchuchartan]")
      |> mes("Now, what do you wish to do?")
      |> mes("My power allows me to create rough")
      |> mes("enchanted stones and to divide a")
      |> mes("pure enchanted stone into rough ones.")
      |> next()
      |> select(["Create rough enchanted stones", "Divide a pure enchanted stone", "Quit."])

    case choice do
      1 -> create_essence(ctx)
      2 -> dismantle_stones(ctx)
      3 -> decline(ctx)
      _ -> ctx
    end
  end

  defp decline(ctx) do
    ctx
    |> mes("[Puchuchartan]")
    |> mes("I see. It's your call.")
    |> mes("Come back when you need me.")
    |> close()
  end

  defp create_essence(ctx) do
    {ctx, element} =
      ctx
      |> mes("[Puchuchartan]")
      |> mes("Do you wish to create rough")
      |> mes("enchanted stones? Which")
      |> mes("property do you wish to create?")
      |> mes("Earth, Water, Fire, Wind...")
      |> mes("...choose one.")
      |> next()
      |> select(["Earth", "Water", "Fire", "Wind"])

    case element do
      1 -> prepare_essence(ctx, 947, 15, 993)
      2 -> prepare_essence(ctx, 946, 20, 991)
      3 -> prepare_essence(ctx, 904, 20, 990)
      4 -> prepare_essence(ctx, 1013, 25, 992)
      _ -> ctx
    end
  end

  defp prepare_essence(ctx, ingredient, amount, essence) do
    ctx =
      ctx
      |> set_local(:consume, ingredient)
      |> set_local(:amount, amount)
      |> set_local(:success, essence)

    if count_item(ctx, get_local(ctx, :consume, 0)) >= get_local(ctx, :amount, 0) do
      ctx =
        ctx
        |> mes("[Puchuchartan]")
        |> mes("I will try to amplify the hidden")
        |> mes("power of natural objects in")
        |> mes("order to create rough enchanted")
        |> mes("stones. Choose one number from")
        |> mes("'1' to '9.' If you wish to cancel")
        |> mes("this request, enter '0.'")
        |> next()

      case ask_creation_number(ctx) do
        {:cancel, ctx} -> ctx
        {:ok, ctx} -> cast_creation_spell(ctx)
      end
    else
      explain_ingredients(ctx)
    end
  end

  defp cast_creation_spell(ctx) do
    ctx = mes(ctx, "[Puchuchartan]")

    essence = get_local(ctx, :success, 0)

    ctx =
      case essence do
        990 ->
          mes(ctx, "I am putting these tails into a")

        991 ->
          mes(ctx, "I am putting these shells into a")

        992 ->
          mes(ctx, "I am putting these shells into a")

        993 ->
          mes(ctx, "I am putting these horns into a")

        _ ->
          ctx
      end

    ctx =
      ctx
      |> mes("boiling pot, and casting a")
      |> mes("sacred incantation. Remember")
      |> mes("the number you entered.")
      |> next()
      |> mes("[Puchuchartan]")
      |> mes("Amba Omba Zatumba! Umba! Ti!")
      |> mes("Umputaun Eulukaba! Umba! Ha!")
      |> mes("Julu Humba Rulala! Umba! La!")
      |> mes("Datuha Ombabalaka! Umba! Si!")
      |> mes("Sunutaba Abulumba! Umba! Si!")
      |> next()

    if Enum.random(1..10) == 1 do
      ctx =
        ctx
        |> mes("[Puchuchartan]")
        |> mes("I guess my power was not enough.")
        |> mes("The natural power I gathered with")
        |> mes("my spell lost focus and was scattered...")

      ctx
      |> delitem(get_local(ctx, :consume, 0), get_local(ctx, :amount, 0))
      |> give_item(910, 1)
      |> next()
      |> mes("[Puchuchartan]")
      |> mes("It seems the spirits of nature")
      |> mes("were not in harmony at the moment.")
      |> mes("However, if you come back later,")
      |> mes("I will try to help you. Of course,")
      |> mes("there will still be the same possibility that I may fail.")
      |> close()
    else
      ctx =
        ctx
        |> mes("[Puchuchartan]")
        |> mes("Here's the enchanted stone you")
        |> mes("wished to have. I created this")
        |> mes("with a lot of effort, so make")
        |> mes("good use of it.")

      ctx = delitem(ctx, get_local(ctx, :consume, 0), get_local(ctx, :amount, 0))
      ctx |> give_item(get_local(ctx, :success, 0), 1) |> close()
    end
  end

  defp explain_ingredients(ctx) do
    ctx = mes(ctx, "[Puchuchartan]")
    essence = get_local(ctx, :success, 0)

    ctx =
      case essence do
        990 ->
          ctx
          |> mes("Fire property...")
          |> mes("I will need natural")
          |> mes("objects that are filled with")
          |> mes("the spirit of fire.")
          |> next()
          |> mes("[Puchuchartan]")
          |> mes("Scorpion which endures the")
          |> mes("blazing heat of the desert")
          |> mes("is brimming with fire energy.")
          |> mes("I need ^3377FF20 Scorpion Tails^000000.")

        991 ->
          ctx
          |> mes("Water property...")
          |> mes("I will need natural")
          |> mes("objects that are filled with")
          |> mes("the spirit of water.")
          |> next()
          |> mes("[Puchuchartan]")
          |> mes("Ambernite...the spirit of")
          |> mes("water is contained within its")
          |> mes("protective shell...")
          |> mes("I will need ^3377FF20 Snail's Shell.^000000")

        992 ->
          ctx
          |> mes("Wind property...")
          |> mes("I will need natural")
          |> mes("objects that are filled with")
          |> mes("the spirit of wind.")
          |> next()
          |> mes("[Puchuchartan]")
          |> mes("Stainer...the beetle")
          |> mes("that flies through the sky")
          |> mes("has the wind's spirit.")
          |> mes("I need ^3377FF25 Rainbow Shells^000000.")

        993 ->
          ctx
          |> mes("Earth property...I need natural")
          |> mes("objects that are filled with")
          |> mes("the spirit of the Earth.")
          |> next()
          |> mes("[Puchuchartan]")
          |> mes("Horn...that dwells in the forest")
          |> mes("is filled with the spirits of")
          |> mes("earth and wood...Horn...")
          |> mes("I need ^3377FF15 Horn^000000 from Horns.")

        _ ->
          ctx
      end

    ctx
    |> mes("[Puchuchartan]")
    |> mes("That's all I need...")
    |> mes("Come back when")
    |> mes("you're ready.")
    |> mes("I will be here.")
    |> close()
  end

  defp dismantle_stones(ctx) do
    {ctx, element} =
      ctx
      |> mes("[Puchuchartan]")
      |> mes("Do you wish to divide a pure")
      |> mes("enchanted stone into rough ones?")
      |> mes("Which property do you want to")
      |> mes("divide? Earth, Water, Fire, Wind... ")
      |> mes("Choose one.")
      |> next()
      |> select(["Earth", "Water", "Fire", "Wind"])

    case element do
      1 -> ask_quantity(set_local(ctx, :divide, 997))
      2 -> ask_quantity(set_local(ctx, :divide, 995))
      3 -> ask_quantity(set_local(ctx, :divide, 994))
      4 -> ask_quantity(set_local(ctx, :divide, 996))
      _ -> ctx
    end
  end

  defp ask_quantity(ctx) do
    {ctx, raw_quantity} =
      ctx
      |> mes("[Puchuchartan]")
      |> mes("Please enter the")
      |> mes("number of enchanted")
      |> mes("stones that you wish")
      |> mes("to divide. I can only")
      |> mes("divide up to 10 at a time.")
      |> next()
      |> input(:int)

    {_, quantity} = Rathena.input_int(raw_quantity, 0, 11)
    ctx = set_local(ctx, :input, quantity)

    cond do
      quantity < 1 or quantity > 10 ->
        ctx
        |> mes("[Puchuchartan]")
        |> mes("Hm? You need to enter")
        |> mes("a number from 1 to 10.")
        |> close()

      count_item(ctx, get_local(ctx, :divide, 0)) < quantity ->
        explain_stone_shortage(ctx, quantity)

      checkweight(ctx, [{908, quantity * 30}]) == 0 ->
        ctx
        |> mes("[Puchuchartan]")
        |> mes("You're carrying too")
        |> mes("many items right now.")
        |> mes("Put some of your stuff")
        |> mes("in Kafra Storage, and then")
        |> mes("come back to me, okay?")
        |> close()

      true ->
        begin_dismantling(ctx)
    end
  end

  defp explain_stone_shortage(ctx, quantity) do
    stone = get_local(ctx, :divide, 0)

    ctx =
      ctx
      |> mes("[Puchuchartan]")
      |> mes("So, you wish to have rough")

    ctx =
      case stone do
        994 ->
          ctx
          |> mes("fire stones? Then I will need")
          |> mes("you to bring #{quantity} pure fire stone.")

        995 ->
          ctx
          |> mes("water stones? Then I'll need")
          |> mes("you to bring #{quantity} pure water stone.")

        996 ->
          ctx
          |> mes("wind stones? Then I will need")
          |> mes("you to bring #{quantity} pure wind stone.")

        997 ->
          ctx
          |> mes("earth stones? Then I'll need")
          |> mes("you to bring #{quantity} pure earth stone.")

        _ ->
          ctx
      end

    ctx
    |> mes("^3377FF#{quantity} #{Rathena.getitemname(stone)}^000000.")
    |> next()
    |> mes("[Puchuchartan]")
    |> mes("That's all I need...")
    |> mes("Come back when")
    |> mes("you're ready.")
    |> mes("I will be here.")
    |> close()
  end

  defp begin_dismantling(ctx) do
    ctx =
      ctx
      |> mes("[Puchuchartan]")
      |> mes("I'll try to revert these")
      |> mes("enchanted stones to their")
      |> mes("rough forms. Enter a number")
      |> mes("from 1 to 9, or enter 0 if")
      |> mes("you decide to cancel.")
      |> next()

    case ask_dismantle_number(ctx) do
      {:cancel, ctx} -> ctx
      {:ok, ctx} -> finish_dismantling(ctx)
    end
  end

  defp finish_dismantling(ctx) do
    ctx =
      ctx
      |> mes("[Puchuchartan]")
      |> mes("I will now chant the")
      |> mes("sacred words. Remember")
      |> mes("the number you entered!")
      |> next()
      |> mes("[Puchuchartan]")
      |> mes("Umba Umba Kalapum! Umba! Ta!")
      |> mes("Lukura Ukulele Um! Umba! Ka!")
      |> mes("Abulaka Tabulakan! Umba! La!")
      |> mes("Ombaludu Zan Kunu! Umba! Ku!")
      |> mes("Kum Tum Lakulakun! Umba! Ha!")
      |> next()
      |> mes("[Puchuchartan]")
      |> mes("Here's the rough enchanted stones")
      |> mes("you wished to have. I created this")
      |> mes("with a lot of effort, so make good")
      |> mes("use of them.")
      |> count_essences()

    stone = get_local(ctx, :divide, 0)

    ctx =
      case stone do
        994 ->
          give_item(ctx, 990, get_local(ctx, :shaman_max, 0))

        995 ->
          give_item(ctx, 991, get_local(ctx, :shaman_max, 0))

        996 ->
          give_item(ctx, 992, get_local(ctx, :shaman_max, 0))

        997 ->
          give_item(ctx, 993, get_local(ctx, :shaman_max, 0))

        _ ->
          ctx
      end

    ctx |> delitem(get_local(ctx, :divide, 0), get_local(ctx, :input, 0)) |> close()
  end

  defp ask_creation_number(ctx) do
    {ctx, raw_number} = input(ctx, :int)
    {_, number} = Rathena.input_int(raw_number, 0, 10)
    ctx = set_local(ctx, :input, number)

    cond do
      number == 0 ->
        {:cancel, decline(ctx)}

      number > 9 ->
        ctx
        |> mes("[Puchuchartan]")
        |> mes("Remember to choose a number")
        |> mes("from 1 to 9.")
        |> next()
        |> ask_creation_number()

      true ->
        {:ok, ctx}
    end
  end

  defp ask_dismantle_number(ctx) do
    {ctx, raw_number} = input(ctx, :int)
    {_, number} = Rathena.input_int(raw_number, 0, 10)
    ctx = set_local(ctx, :input2, number)

    cond do
      number == 0 ->
        ctx =
          ctx
          |> mes("[Puchuchartan]")
          |> mes("You want to cancel?")
          |> mes("Well, if you change your")
          |> mes("mind, feel free to come")
          |> mes("ask me to help at any time.")
          |> close()

        {:cancel, ctx}

      number > 9 ->
        ctx
        |> mes("[Puchuchartan]")
        |> mes("Hm? You need to enter")
        |> mes("a number from 1 to 9.")
        |> next()
        |> ask_dismantle_number()

      true ->
        {:ok, ctx}
    end
  end

  defp count_essences(ctx) do
    if get_local(ctx, :sha_man, 0) == get_local(ctx, :input, 0) do
      ctx
    else
      ctx = set_local(ctx, :shaman_max, get_local(ctx, :shaman_max, 0) + Enum.random(6..10))
      ctx |> set_local(:sha_man, get_local(ctx, :sha_man, 0) + 1) |> count_essences()
    end
  end
end
