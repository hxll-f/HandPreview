--- STEAMODDED HEADER
--- MOD_NAME: Hand Preview
--- MOD_ID: handpreview
--- MOD_AUTHOR: [Toeler]
--- MOD_DESCRIPTION: A utility mod to list the hands that you can make. v1.1.0

----------------------------------------------
------------MOD CODE -------------------------

function SMODS.INIT.handpreview()
	if not HandPreview then
		HandPreview = {
			TAG = "HandPreview"
		}
	end
	if not G.SETTINGS.HandPreview then
		G.SETTINGS.HandPreview = {
			preview_count = 3,
			include_facedown = false,
			include_breakdown = false,
			position_locked = true,
			position = nil,
			anchor = "Top Right"
		}
	end
	HandPreview.settings = G.SETTINGS.HandPreview

	local balalib_mod = SMODS.findModByID("balalib")
	if not balalib_mod then
		error("Hand Preview requires BalaLib mod to be installed")
	end

	local settings = HandPreview.settings

	-- Fill in anything a settings file saved by an older version is missing so
	-- the hot path never has to nil-check.
	local DEFAULT_SETTINGS = {
		preview_count = 3,
		include_facedown = false,
		include_breakdown = false,
		position_locked = true,
		anchor = "Top Right"
	}
	for k, v in pairs(DEFAULT_SETTINGS) do
		if settings[k] == nil then settings[k] = v end
	end

	-- Off by default, and takes its message in pieces so nothing is built while
	-- it is. This used to replace the global sendDebugMessage, which tagged every
	-- other mod's logging as HandPreview and built a string on every settings
	-- write - that is, on every frame of a window drag.
	HandPreview.debug = HandPreview.debug or false
	local function debug_msg(...)
		if not HandPreview.debug then return end
		local parts = { ... }
		for i = 1, #parts do parts[i] = tostring(parts[i]) end
		sendDebugMessage(table.concat(parts), HandPreview.TAG)
	end

	local function get_setting(name)
		return settings[name]
	end

	-- G:save_settings() writes to disk. Dragging the window called it once per
	-- frame, so writes are coalesced and flushed once things settle down.
	local save_delay = 0
	local function request_save()
		save_delay = 0.4
	end

	local function flush_settings(dt)
		if save_delay > 0 then
			save_delay = save_delay - dt
			if save_delay <= 0 then
				save_delay = 0
				G:save_settings()
			end
		end
	end

	local function set_setting(name, value)
		debug_msg('set_setting ', name, ' to ', value)

		settings[name] = value
		request_save()
	end

	----------------------------------------------
	--- Container
	----------------------------------------------

	HandPreviewContainer = MoveableContainer:extend()
	function HandPreviewContainer:init(args)
		args.header = {
			n = G.UIT.T,
			config = {
				text = 'Possible Hands',
				scale = 0.3,
				colour = G.C.WHITE
			}
		}
		args.nodes = {
			{
				n = G.UIT.R,
				config = {
					minh = 0.1
				},
				nodes = {}
			},
			{ n = G.UIT.R, config = { id = "hand_list" } }
		}
		args.config = args.config or {}
		args.config.locked = get_setting('position_locked')
		args.config.anchor = get_setting('anchor')
		local function open_settings(back_func)
			G.FUNCS.open_hand_preview_settings(nil, nil, back_func)
		end
		args.config.settings_func = open_settings

		MoveableContainer.init(self, args)
	end

	function HandPreviewContainer:drag(offset)
		MoveableContainer.drag(self, offset)

		local x, y = self:get_relative_pos()
		local position = settings.position
		if type(position) == 'table' then
			position.x, position.y = x, y
		else
			settings.position = { x = x, y = y }
		end
		request_save()
	end

	-- get_UIE_by_ID walks the whole UI tree, so the row container is looked up
	-- once and kept.
	function HandPreviewContainer:get_hand_list()
		local list = self.hand_list_UIE
		if not list then
			list = self:get_UIE_by_ID("hand_list")
			self.hand_list_UIE = list
		end
		return list
	end

	function HandPreviewContainer:add_hand(hand_str)
		local list = self:get_hand_list()
		if not list then return end

		self:add_child({
			n = G.UIT.R,
			nodes = {
				{
					n = G.UIT.T,
					config = {
						text = hand_str,
						scale = 0.3,
						colour = G.C.WHITE
					}
				},
			}
		}, list)
	end

	function HandPreviewContainer:remove_all_hands()
		local list = self:get_hand_list()
		if list then remove_all(list.children) end
	end

	-- UIBox:add_child() recalculates the entire box, so adding rows one at a
	-- time recalculated it once per row. Build the rows, then recalculate once.
	function HandPreviewContainer:set_hands(lines, count)
		local list = self:get_hand_list()
		if not list then return end

		remove_all(list.children)
		for i = 1, count do
			self:set_parent_child({
				n = G.UIT.R,
				nodes = {
					{
						n = G.UIT.T,
						config = {
							text = lines[i],
							scale = 0.3,
							colour = G.C.WHITE
						}
					},
				}
			}, list)
		end
		self:recalculate()
	end

	-- BalaLib's update looks this row up by walking the whole UI tree, every
	-- frame. It never moves, so look it up once.
	function HandPreviewContainer:update(dt)
		UIBox.update(self, dt)

		local buttons = self.button_container_UIE
		if not buttons then
			buttons = self:get_UIE_by_ID('button_container')
			self.button_container_UIE = buttons
		end
		if buttons then buttons.states.visible = self.states.collide.is end
	end

	function HandPreviewContainer:bl_toggle_lock()
		MoveableContainer.bl_toggle_lock(self)

		set_setting('position_locked', not self.states.drag.can)
	end

	function HandPreviewContainer:bl_cycle_anchor_point()
		MoveableContainer.bl_cycle_anchor_point(self)

		set_setting('anchor', self.states.anchor)
		local x, y = self:get_relative_pos()
		set_setting('position', { x = x, y = y })
	end

	local function get_default_pos()
		return { x = G.consumeables.T.x + G.consumeables.T.w, y = G.consumeables.T.y + G.consumeables.T.h + 0.4 }
	end

	----------------------------------------------
	--- Hand analysis
	----------------------------------------------

	local DEFAULT_ORDER = { "Flush Five", "Flush House", "Five of a Kind", "Royal Flush", "Straight Flush",
		"Four of a Kind", "Full House", "Flush", "Straight", "Three of a Kind",
		"Two Pair", "Pair", "High Card" }
	local DEFAULT_SUITS = { "Spades", "Hearts", "Clubs", "Diamonds" }

	-- Hard ceiling on evaluate_poker_hand() calls per refresh. A typical hand
	-- needs about seven; the worst seen in testing - eleven cards held with Four
	-- Fingers, Shortcut and Smeared Joker, breakdown on - needed 160.
	local MAX_EVALUATIONS = 256

	local function hand_order()
		return G.handlist or DEFAULT_ORDER
	end

	local function suit_list()
		if SMODS.Suit and SMODS.Suit.obj_buffer and SMODS.Suit.obj_buffer[1] then
			return SMODS.Suit.obj_buffer
		end
		return DEFAULT_SUITS
	end

	-- Minimum card counts for a flush/straight, honouring Four Fingers.
	local function min_flush_len()
		if SMODS.four_fingers then return SMODS.four_fingers('flush') or 5 end
		return next(find_joker('Four Fingers')) and 4 or 5
	end

	local function min_straight_len()
		if SMODS.four_fingers then return SMODS.four_fingers('straight') or 5 end
		return next(find_joker('Four Fingers')) and 4 or 5
	end

	local function can_skip_ranks()
		if SMODS.shortcut then return SMODS.shortcut() end
		return next(find_joker('Shortcut')) and true or false
	end

	-- Scratch tables, reused across refreshes so analysis allocates next to nothing.
	local pool, forced, forced_set = {}, {}, {}
	local groups, rank_ids, card_rank = {}, {}, {}
	local suit_pool, suit_groups, suit_member, suit_sets = {}, {}, {}, {}
	local subset, key_ids = {}, {}
	local pick, run, rank_count, combo_idx = {}, {}, {}, {}
	local slot_group, restore_slot, restore_card, pad_base = {}, {}, {}, {}
	local straight_keys, mixed_keys, sorted_ranks = {}, {}, {}
	local flush_labels = {}
	local unique_hands, seen_subsets = {}, {}
	local EMPTY = {}

	local function clear_table(t)
		for k in pairs(t) do t[k] = nil end
	end

	-- Ties are broken so that rows do not reshuffle between refreshes; table.sort
	-- is not stable, and same-rank cards are common.
	local function by_card_id(a, b)
		if a.base.id ~= b.base.id then return a.base.id < b.base.id end
		return (a.sort_id or a.ID or 0) < (b.sort_id or b.ID or 0)
	end

	local function trim(t, n)
		for i = #t, n + 1, -1 do t[i] = nil end
	end

	-- Sorted card identity string; identical card sets produce identical keys.
	local function cards_key(cards, n)
		for i = 1, n do
			local card = cards[i]
			key_ids[i] = card.sort_id or card.ID or 0
		end
		for i = 2, n do
			local v = key_ids[i]
			local j = i - 1
			while j >= 1 and key_ids[j] > v do
				key_ids[j + 1] = key_ids[j]
				j = j - 1
			end
			key_ids[j + 1] = v
		end
		local key = tostring(key_ids[1])
		for i = 2, n do key = key .. ',' .. key_ids[i] end
		return key
	end

	-- Walks ranks the same way the game's get_straight does: position 1 and 14
	-- are both an Ace, and Shortcut allows a single missing rank at a time.
	local function collect_run(present, start, skips, out)
		local n, position, skipped = 0, start, false
		while position <= 14 and n < 5 do
			local rank = (position == 1) and 14 or position
			if present[rank] then
				n = n + 1
				out[n] = rank
				skipped = false
			elseif skips and not skipped and position ~= 14 and n > 0 then
				skipped = true
			else
				break
			end
			position = position + 1
		end
		return n
	end

	local function has_straight(present, min_len, skips)
		for start = 1, 14 do
			local rank = (start == 1) and 14 or start
			if present[rank] and collect_run(present, start, skips, run) >= min_len then
				return true
			end
		end
		return false
	end

	local function analyse_hand(cards)
		clear_table(unique_hands)
		clear_table(seen_subsets)
		clear_table(forced_set)
		clear_table(groups)
		clear_table(card_rank)

		local include_facedown = settings.include_facedown
		-- Only controls the extra work that fills in the per-row breakdown text;
		-- which rows appear is always worked out in full.
		local want_all = settings.include_breakdown and true or false

		local npool, nforced = 0, 0
		for i = 1, #cards do
			local card = cards[i]
			if card.ability and card.ability.forced_selection then
				nforced = nforced + 1
				forced[nforced] = card
				forced_set[card] = true
			end
			if include_facedown or card.facing ~= 'back' then
				npool = npool + 1
				pool[npool] = card
			end
		end
		-- Forced cards join every selection whether or not they passed the
		-- face-down filter, so they belong in the pool the hands are built from.
		for i = 1, nforced do
			local card = forced[i]
			local present = false
			for j = 1, npool do
				if pool[j] == card then present = true break end
			end
			if not present then
				npool = npool + 1
				pool[npool] = card
			end
		end
		trim(pool, npool)
		trim(forced, nforced)

		-- The game never plays more than five cards, so a hand that forces more
		-- than that has nothing to preview.
		if nforced > 5 or npool == 0 then return 0 end

		-- Rank groups. get_id() rolls a fresh random value for every Stone Card,
		-- so it is called exactly once per card.
		local nranks = 0
		for i = 1, npool do
			local card = pool[i]
			local id = card:get_id()
			if id and id > 0 then
				card_rank[card] = id
				local group = groups[id]
				if not group then
					group = {}
					groups[id] = group
					nranks = nranks + 1
					rank_ids[nranks] = id
				end
				group[#group + 1] = card
			end
		end
		trim(rank_ids, nranks)

		local order = hand_order()
		local evaluations = 0

		-- Assembles the given cards plus the forced ones into a selection and asks
		-- the game what it scores as. Returns true when it evaluated, false when
		-- the same selection was already covered, and nil when the game could
		-- never make this selection (a hand is at most five cards).
		local function emit(list, count)
			if evaluations >= MAX_EVALUATIONS then return nil end

			local n = nforced
			for i = 1, nforced do subset[i] = forced[i] end
			for i = 1, count do
				local card = list[i]
				if card and not forced_set[card] then
					n = n + 1
					if n > 5 then return nil end
					subset[n] = card
				end
			end
			if n == 0 then return nil end
			trim(subset, n)

			local key = cards_key(subset, n)
			if seen_subsets[key] then return false end
			seen_subsets[key] = true
			evaluations = evaluations + 1

			-- evaluate_poker_hand rather than G.FUNCS.get_poker_hand_info: the
			-- latter localizes a name this mod never reads and, under Steamodded,
			-- fires an evaluate_poker_hand joker context. Neither belongs in a
			-- preview, and both cost more than the evaluation itself.
			local results = evaluate_poker_hand(subset)
			for i = 1, #order do
				local hand_type = order[i]
				local matches = results[hand_type]
				if matches and next(matches) then
					local scoring_hand = matches[1]
					if scoring_hand and scoring_hand[1] then
						local hash = cards_key(scoring_hand, #scoring_hand)
						if not unique_hands[hash] then
							unique_hands[hash] = {
								hand_type = hand_type,
								scoring_hand = scoring_hand
							}
						end
					end
					break
				end
			end
			return true
		end

		-- Forced cards are part of every selection the game allows, so whenever a
		-- rank group has to be represented they are the ones to use: picking
		-- anything else just spends a slot on a duplicate.
		local function take(group, count, out, at, from_end)
			local written = 0
			if nforced > 0 then
				for i = 1, #group do
					if written >= count then break end
					if forced_set[group[i]] then
						written = written + 1
						out[at + written] = group[i]
					end
				end
			end
			local first, last, step = 1, #group, 1
			if from_end then first, last, step = #group, 1, -1 end
			for i = first, last, step do
				if written >= count then break end
				if not forced_set[group[i]] then
					written = written + 1
					out[at + written] = group[i]
				end
			end
			return written
		end

		local function representative(group, from_end)
			if nforced > 0 then
				for i = 1, #group do
					if forced_set[group[i]] then return group[i] end
				end
			end
			return from_end and group[#group] or group[1]
		end

		local straight_len = min_straight_len()
		local flush_len = min_flush_len()
		local skips = can_skip_ranks()

		-- Suit membership for every card, worked out once. is_suit() is not a
		-- plain field read - it accounts for Wild Cards, Smeared Joker and Stone
		-- Cards, and looks jokers up every time it is called.
		local suits = suit_list()
		local nsuits = #suits
		for s = 1, nsuits do
			local set = suit_sets[s]
			if not set then
				set = {}
				suit_sets[s] = set
			else
				clear_table(set)
			end
			local suit = suits[s]
			for i = 1, npool do
				if pool[i]:is_suit(suit, nil, true) then set[pool[i]] = true end
			end
		end

		-- How many cards of one suit this pick holds, once the forced cards join
		-- it: flush_len or more and the selection scores as a flush hand.
		local function flush_score(n)
			local best = 0
			for s = 1, nsuits do
				local set = suit_sets[s]
				local matched = 0
				for i = 1, n do
					if set[pick[i]] then matched = matched + 1 end
				end
				for i = 1, nforced do
					local card = forced[i]
					if set[card] then
						local used = false
						for j = 1, n do
							if pick[j] == card then used = true break end
						end
						if not used then matched = matched + 1 end
					end
				end
				if matched > best then best = matched end
			end
			return best
		end

		local function is_flush_pick(n)
			return flush_score(n) >= flush_len
		end

		-- Rebuilds a pick that came out all one suit - and so scores as a flush
		-- hand, hiding the plain one - out of different cards of the same ranks.
		-- slot_group[i] holds the rank group pick[i] was taken from. Returns true
		-- when it managed to change the pick.
		local function break_flush(n)
			local score = flush_score(n)
			if score < flush_len then return false end

			-- One swap is not always enough, so swaps that thin the suit out are
			-- kept and the next slot is tried on top of them.
			local restored = 0
			for i = 1, n do
				local group = slot_group[i]
				local original = pick[i]
				if group and #group > 1 and not forced_set[original] then
					for x = 1, #group do
						local candidate = group[x]
						if candidate ~= original then
							local duplicate = false
							for j = 1, n do
								if j ~= i and pick[j] == candidate then duplicate = true break end
							end
							if not duplicate then
								pick[i] = candidate
								local swapped = flush_score(n)
								if swapped < score then
									score = swapped
									restored = restored + 1
									restore_slot[restored] = i
									restore_card[restored] = original
									break
								end
								pick[i] = original
							end
						end
					end
					if score < flush_len then return true end
				end
			end

			for i = 1, restored do pick[restore_slot[i]] = restore_card[i] end
			return false
		end

		-- Visits every straight that can be built from these rank groups. Ranks
		-- follow one another, or leave single gaps when Shortcut is around - and
		-- with Shortcut a rank may be stepped over even though the hand holds it,
		-- so this walks the alternatives rather than one greedy run. The ranks of
		-- the current run are in run[1..n].
		--
		-- Runs printing the same "low-high" text are normally only worth visiting
		-- once, except that one of them may be all one suit (and so score as a
		-- straight flush) while another is not: visit() returns 2 when it managed
		-- to build a plain straight and 1 when it only managed a flush, and a text
		-- that has only been seen as a flush is given a second chance. Callers
		-- that need every distinct run pass dedupe = false.
		local function for_each_straight(present, min_len, visit, dedupe)
			if dedupe == nil then dedupe = true end
			clear_table(straight_keys)

			local function step(position, n)
				if n >= min_len then
					if not dedupe then
						visit(n)
					else
						-- A run that starts on the low Ace still sorts the Ace
						-- last, and such a straight prints its second-highest
						-- card, so the text depends on all three of these.
						local low, high, second
						if run[1] == 14 then
							low, high, second = run[2], 14, run[n]
						else
							low, high, second = run[1], run[n], run[n - 1] or 0
						end
						-- A run with room for a passenger prints something different
						-- from a longer run with the same range, so the two are
						-- kept apart while the breakdown is being filled in.
						local key = (low * 4096 + high * 64 + second) * 2 +
							((want_all and n < 5) and 1 or 0)
						if (straight_keys[key] or 0) < 2 then
							local state = visit(n) or 2
							if state > (straight_keys[key] or 0) then
								straight_keys[key] = state
							end
						end
					end
				end
				if n >= 5 then return end

				for gap = 1, (skips and 2 or 1) do
					local next_position = position + gap
					-- Position 14 is the high Ace, which cannot be stepped over.
					if next_position <= 14 and not (gap == 2 and position + 1 == 14) then
						local rank = (next_position == 1) and 14 or next_position
						if present[rank] then
							run[n + 1] = rank
							step(next_position, n + 1)
						end
					end
				end
			end

			for start = 1, 14 do
				local rank = (start == 1) and 14 or start
				if present[rank] then
					run[1] = rank
					step(start, 1)
				end
			end
		end

		-- Adds one more card to a run that is shorter than five cards. Four Fingers
		-- leaves room for a passenger, and it ends up in the scored hand, which
		-- changes the range the row prints.
		local function emit_padded_straight(present, n, spare, spare_count, allow_break)
			for i = 1, n do pad_base[i] = pick[i] end

			local tried = 0
			for x = 1, spare_count do
				if tried >= 8 then break end
				local card = spare[x]
				local used = false
				for i = 1, n do
					if pad_base[i] == card then used = true break end
				end
				if not used then
					tried = tried + 1
					for i = 1, n do pick[i] = pad_base[i] end
					pick[n + 1] = card
					emit(pick, n + 1)

					-- The passenger can push the selection into being all one suit,
					-- which would hide the plain straight again.
					if allow_break then
						for i = 1, n do slot_group[i] = present[run[i]] end
						slot_group[n + 1] = nil
						if break_flush(n + 1) then emit(pick, n + 1) end
					end
				end
			end

			for i = 1, n do pick[i] = pad_base[i] end
		end

		-- Straights. `spare` holds the cards that may ride along, which for a
		-- straight flush is the rest of the suit.
		local function emit_straights(present, min_len, spare, spare_count)
			local found = false
			for_each_straight(present, min_len, function(n)

				for i = 1, n do
					local group = present[run[i]]
					slot_group[i] = group
					pick[i] = representative(group)
				end
				local result = emit(pick, n)
				if result then found = true end
				local usable = result ~= nil

				-- If that pick happens to be all one suit it scores as a straight
				-- flush, and the plain straight would go unreported.
				local plain = not is_flush_pick(n)
				if not plain and break_flush(n) then
					plain = true
					result = emit(pick, n)
					if result then found = true end
					if result ~= nil then usable = true end
				end

				-- Padding uses whatever pick is in hand, which is the one that is not
				-- a flush when such a pick was found.
				if n < 5 and want_all then
					if spare then
						emit_padded_straight(present, n, spare, spare_count)
					elseif run[1] == 14 and run[2] == 2 then
						-- An Ace-low straight prints its second-highest card, so a
						-- spare Ace turns "Ace-4" into "Ace-Ace".
						local aces = present[14]
						if aces and #aces > 1 then
							emit_padded_straight(present, n, aces, #aces, true)
						end
					end
				end

				-- A second pick from the other end of each rank group, which can
				-- land on a different suit or a different duplicate.
				local alt = false
				for i = 1, n do
					local group = present[run[i]]
					pick[i] = representative(group, true)
					if #group > 1 then alt = true end
				end
				if alt then
					result = emit(pick, n)
					if result then found = true end
					if result ~= nil then usable = true end
				end

				-- Nothing about this run could be turned into a legal selection, so
				-- another run printing the same text still deserves a look.
				if not usable then return 0 end
				return plain and 2 or 1
			end)
			return found
		end

		-- Would this all-one-suit selection score as a plain Flush, or as
		-- something that outranks it? Pure integer work, no evaluation.
		local function is_plain_flush(cards_in, n)
			clear_table(rank_count)
			local highest = 0

			local function tally(card)
				local id = card_rank[card]
				if id then
					local count = (rank_count[id] or 0) + 1
					rank_count[id] = count
					if count > highest then highest = count end
				end
			end

			for i = 1, n do tally(cards_in[i]) end
			-- Forced cards come along with the selection and can turn it into
			-- something that outranks a plain flush.
			for i = 1, nforced do
				local card = forced[i]
				local used = false
				for j = 1, n do
					if cards_in[j] == card then used = true break end
				end
				if not used then tally(card) end
			end
			if highest >= 4 then return false end -- Four/Five of a Kind, or Flush Five

			local trips, pairs_found = 0, 0
			for _, count in pairs(rank_count) do
				if count >= 3 then trips = trips + 1 end
				if count >= 2 then pairs_found = pairs_found + 1 end
			end
			if trips >= 1 and pairs_found >= 2 then return false end -- Flush House

			return not has_straight(rank_count, straight_len, skips) -- Straight Flush
		end

		-- Selections of this suit that read as a plain Flush. The Flush row is
		-- labelled with the printed suit of the selection's lowest card, which a
		-- Wild Card can make differ from the suit that actually forms the flush,
		-- so one selection per distinct label is emitted.
		local function emit_plain_flushes(cards_in, count, size, labels)
			for i = 1, size do combo_idx[i] = i end
			local guard = 0
			while true do
				guard = guard + 1
				if guard > 400 then return end

				local lowest
				for i = 1, size do
					local card = cards_in[combo_idx[i]]
					pick[i] = card
					if not lowest or by_card_id(card, lowest) then lowest = card end
				end

				local label = lowest and lowest.base.suit
				if label and not labels[label] and is_plain_flush(pick, size) then
					if emit(pick, size) then
						labels[label] = true
						-- Without the breakdown the row is just "Flush", so one is enough.
						if not want_all then return end
					end
				end

				local i = size
				while i >= 1 and combo_idx[i] == count - size + i do i = i - 1 end
				if i < 1 then return end
				combo_idx[i] = combo_idx[i] + 1
				for j = i + 1, size do combo_idx[j] = combo_idx[j - 1] + 1 end
			end
		end

		-- With Four Fingers a four card flush and a four card straight fit in the
		-- same five card selection, and the game scores that as a straight flush
		-- even though the five cards are not all one suit. Builds straights that
		-- lean on this suit and tops them up with a spare card of it.
		-- The row's text comes from the whole scored hand, which here is the flush
		-- cards plus the rest of the straight. Two selections printing the same
		-- range are not worth evaluating twice.
		local function mixed_is_new(n, extra_rank)
			local count = 0
			for i = 1, n do
				count = count + 1
				sorted_ranks[count] = card_rank[pick[i]] or 0
			end
			if extra_rank then
				count = count + 1
				sorted_ranks[count] = extra_rank
			end
			for i = 2, count do
				local v = sorted_ranks[i]
				local j = i - 1
				while j >= 1 and sorted_ranks[j] > v do
					sorted_ranks[j + 1] = sorted_ranks[j]
					j = j - 1
				end
				sorted_ranks[j + 1] = v
			end

			local key = sorted_ranks[1] * 4096 + sorted_ranks[count] * 64 + (sorted_ranks[count - 1] or 0)
			if mixed_keys[key] then return false end
			mixed_keys[key] = true
			return true
		end

		local function emit_mixed_straight_flushes(count)
			clear_table(mixed_keys)
			for_each_straight(groups, straight_len, function(len)
				local suited = 0
				for i = 1, len do
					local group = groups[run[i]]
					-- A forced card is in the selection either way, so if this rank
					-- has one it is what the slot should spend itself on, whatever
					-- its suit; a card of the suit can still be picked up below.
					local chosen = nforced > 0 and representative(group) or nil
					if not chosen or not forced_set[chosen] then
						chosen = nil
						for x = 1, #group do
							if suit_member[group[x]] then chosen = group[x] break end
						end
						chosen = chosen or representative(group)
					end
					if suit_member[chosen] then suited = suited + 1 end
					pick[i] = chosen
				end

				if suited >= flush_len then
					if mixed_is_new(len) then emit(pick, len) end
				elseif suited == flush_len - 1 and len < 5 then
					-- One spare card of the suit completes the flush. Which one it
					-- is changes the row's text, so try each. A forced card left out
					-- of the run joins the selection on its own.
					local outstanding = false
					for i = 1, nforced do
						local card = forced[i]
						local used = false
						for j = 1, len do
							if pick[j] == card then used = true break end
						end
						if not used then outstanding = true break end
					end

					if outstanding then
						if mixed_is_new(len) then emit(pick, len) end
					else
						for x = 1, count do
							local card = suit_pool[x]
							local used = false
							for i = 1, len do
								if pick[i] == card then used = true break end
							end
							if not used and mixed_is_new(len, card_rank[card] or 0) then
								pick[len + 1] = card
								emit(pick, len + 1)
							end
						end
					end
				end
			end, false)
		end

		-- Gathers the cards that count as this suit, along with their rank groups.
		local function collect_suit(index)
			suit_member = suit_sets[index]

			local count = 0
			for i = 1, npool do
				if suit_member[pool[i]] then
					count = count + 1
					suit_pool[count] = pool[i]
				end
			end
			trim(suit_pool, count)

			clear_table(suit_groups)
			for i = 1, count do
				local card = suit_pool[i]
				local id = card_rank[card]
				if id then
					local group = suit_groups[id]
					if not group then
						group = {}
						suit_groups[id] = group
					end
					group[#group + 1] = card
				end
			end
			return count
		end

		-- Flush, Flush House and Flush Five: a bounded handful of selections.
		local function emit_flush_hands(index)
			local count = collect_suit(index)
			if count < flush_len then return end

			for _, group in pairs(suit_groups) do
				if #group >= 5 then
					emit(pick, take(group, 5, pick, 0))
				end
			end

			for id_a, group_a in pairs(suit_groups) do
				if #group_a >= 3 then
					for id_b, group_b in pairs(suit_groups) do
						if id_b ~= id_a and #group_b >= 2 then
							take(group_a, 3, pick, 0)
							take(group_b, 2, pick, 3)
							emit(pick, 5)
						end
					end
				end
			end

			local upper = count < 5 and count or 5
			clear_table(flush_labels)
			for size = flush_len, upper do
				emit_plain_flushes(suit_pool, count, size, flush_labels)
			end
		end

		-- Straight flushes, which with Shortcut can run to a lot of selections.
		local function emit_straight_flushes(index)
			local count = collect_suit(index)
			if count < flush_len then return end

			emit_straights(suit_groups, straight_len, suit_pool, count)
			if flush_len < 5 or straight_len < 5 then
				emit_mixed_straight_flushes(count)
			end
		end

		-- The forced cards on their own: the smallest selection the game allows.
		if nforced > 0 then emit(EMPTY, 0) end

		-- High Card. The row shows the best card in the hand, which the original
		-- found by evaluating every single-card selection.
		if npool > 0 then
			-- The row names the highest rank, but get_highest() picks by nominal
			-- value, which a Stone Card drags below everything else - so among
			-- cards of the same rank take the one that would actually win.
			local best, second
			local best_id, best_nominal, second_id = -1, 0, -1
			for i = 1, npool do
				local card = pool[i]
				local id = card.base and card.base.id or 0
				local nominal = card:get_nominal()
				if id > best_id then
					second, second_id = best, best_id
					best, best_id, best_nominal = card, id, nominal
				elseif id == best_id and nominal > best_nominal then
					best, best_nominal = card, nominal
				elseif id > second_id then
					second, second_id = card, id
				end
			end
			pick[1] = best
			emit(pick, 1)
			if nforced > 0 and second then
				-- The best card may pair up with a forced card, in which case the
				-- runner-up is what the High Card row ends up showing.
				pick[1] = second
				emit(pick, 1)
			end
		end

		-- Pair / Three of a Kind / Four of a Kind / Five of a Kind
		for i = 1, nranks do
			local group = groups[rank_ids[i]]
			local count = #group
			if count > 5 then count = 5 end
			for n = 2, count do
				take(group, n, pick, 0)
				emit(pick, n)
				for s = 1, n do slot_group[s] = group end
				if break_flush(n) then emit(pick, n) end
			end
		end

		-- Two Pair and Full House. Both are also built a second time from the far
		-- end of each rank group: when the obvious pick happens to be all one
		-- suit it scores as a flush hand instead, and the mixed-suit version is
		-- what reports the plain hand.
		for i = 1, nranks do
			local group_a = groups[rank_ids[i]]
			if #group_a >= 2 then
				for j = i + 1, nranks do
					local group_b = groups[rank_ids[j]]
					if #group_b >= 2 then
						take(group_a, 2, pick, 0)
						take(group_b, 2, pick, 2)
						slot_group[1], slot_group[2] = group_a, group_a
						slot_group[3], slot_group[4] = group_b, group_b
						emit(pick, 4)
						if break_flush(4) then emit(pick, 4) end
						if #group_a > 2 or #group_b > 2 then
							take(group_a, 2, pick, 0, true)
							take(group_b, 2, pick, 2, true)
							emit(pick, 4)
						end
					end
				end
			end
		end

		for i = 1, nranks do
			local group_a = groups[rank_ids[i]]
			if #group_a >= 3 then
				for j = 1, nranks do
					if j ~= i then
						local group_b = groups[rank_ids[j]]
						if #group_b >= 2 then
							take(group_a, 3, pick, 0)
							take(group_b, 2, pick, 3)
							slot_group[1], slot_group[2], slot_group[3] = group_a, group_a, group_a
							slot_group[4], slot_group[5] = group_b, group_b
							emit(pick, 5)
							if break_flush(5) then emit(pick, 5) end
							if #group_a > 3 or #group_b > 2 then
								take(group_a, 3, pick, 0, true)
								take(group_b, 2, pick, 3, true)
								emit(pick, 5)
							end
						end
					end
				end
			end
		end

		-- Flush family, one suit at a time. These come before the straights
		-- because they are cheap and fixed in number, whereas the straight walk
		-- can run long: if the evaluation ceiling is ever reached, it should cost
		-- detail on the straight rows rather than lose a flush row outright.
		for i = 1, nsuits do
			emit_flush_hands(i)
		end

		-- Straight, then Straight Flush
		emit_straights(groups, straight_len)
		for i = 1, nsuits do
			emit_straight_flushes(i)
		end

		debug_msg('analysed hand with ', evaluations, ' evaluations')
		return evaluations
	end

	----------------------------------------------
	--- Display
	----------------------------------------------

	local grouped_hands = {}
	local lines, displayed_lines = {}, {}
	local displayed_count = -1

	local function by_description(a, b)
		local a_high = a:match("^(.-)%s") or a
		local b_high = b:match("^(.-)%s") or b
		-- Fall back to the whole string so equal leading values keep a stable
		-- order instead of shuffling around between refreshes.
		if a_high ~= b_high then return a_high > b_high end
		return a < b
	end

	local function describe_full_house(cards)
		clear_table(rank_count)
		for i = 1, #cards do
			local value = cards[i].base.value
			rank_count[value] = (rank_count[value] or 0) + 1
		end
		local first, second = nil, nil
		for rank, count in pairs(rank_count) do
			if count >= 3 then
				first = rank
			elseif not second or rank_count[second] < count then
				second = rank
			end
		end
		if not first or not second then return nil end
		return first .. "s over " .. second .. "s"
	end

	-- Builds the text rows for everything analyse_hand found. Returns the count.
	local function build_lines()
		clear_table(grouped_hands)

		local highest_card_value = nil
		for _, info in pairs(unique_hands) do
			local hand_type = info.hand_type
			local cards = info.scoring_hand
			table.sort(cards, by_card_id)

			local description = nil
			if hand_type == "High Card" then
				if not highest_card_value or cards[1].base.id > highest_card_value then
					description = cards[1].base.value
					highest_card_value = cards[1].base.id
				end
			elseif hand_type == "Pair" or hand_type == "Three of a Kind" or hand_type == "Four of a Kind" or
				hand_type == "Five of a Kind" or hand_type == "Flush Five" then
				description = cards[1].base.value .. "s"
			elseif hand_type == "Two Pair" then
				description = cards[3].base.value .. "s & " .. cards[1].base.value .. "s"
			elseif hand_type == "Straight" or hand_type == "Straight Flush" then
				if cards[1].base.value == '2' and cards[#cards].base.value == 'Ace' then
					description = cards[#cards].base.value .. "-" .. cards[#cards - 1].base.value
				else
					description = cards[1].base.value .. "-" .. cards[#cards].base.value
				end
			elseif hand_type == "Flush" then
				description = cards[1].base.suit
			elseif hand_type == "Full House" or hand_type == "Flush House" then
				description = describe_full_house(cards)
			end

			-- A hand type is listed once it has been found, whether or not this
			-- mod knows how to describe it.
			local group = grouped_hands[hand_type]
			if not group then
				group = { n = 0 }
				grouped_hands[hand_type] = group
			end

			if description then
				local is_duplicate = false
				for i = 1, group.n do
					if group[i] == description then
						is_duplicate = true
						break
					end
				end

				if not is_duplicate then
					if hand_type == "High Card" then
						group[1] = description
						group.n = 1
					else
						group.n = group.n + 1
						group[group.n] = description
					end
				end
			end
		end

		local order = hand_order()
		local max_hands = settings.preview_count or 0
		local include_descriptions = settings.include_breakdown
		local count = 0

		for i = 1, #order do
			local hand_type = order[i]
			local group = grouped_hands[hand_type]
			if group then
				local text = hand_type
				if include_descriptions and group.n > 0 then
					-- Sort descriptions in value order for multiple entries in the same hand type
					table.sort(group, by_description)
					text = text .. ": " .. table.concat(group, ", ", 1, group.n)
				end

				count = count + 1
				lines[count] = text

				if count >= max_hands then break end
			end
		end

		trim(lines, count)
		return count
	end

	local function refresh_display()
		local count = build_lines()

		local changed = (count ~= displayed_count)
		if not changed then
			for i = 1, count do
				if lines[i] ~= displayed_lines[i] then
					changed = true
					break
				end
			end
		end
		if not changed then return end

		for i = 1, count do displayed_lines[i] = lines[i] end
		trim(displayed_lines, count)
		displayed_count = count

		HandPreview.container:set_hands(lines, count)
	end

	----------------------------------------------
	--- Change detection
	----------------------------------------------

	local suit_index = nil
	local function suit_key(suit)
		if not suit_index then
			suit_index = {}
			local suits = suit_list()
			for i = 1, #suits do suit_index[suits[i]] = i end
		end
		return suit_index[suit] or 0
	end

	-- Integer summary of everything the preview depends on. No allocations, no
	-- sorting and no string building, so running it every frame is free.
	local function hand_fingerprint()
		local cards = G.hand and G.hand.cards
		if not cards then return 0, 0 end

		local a, b = #cards, 0
		for i = 1, #cards do
			local card = cards[i]
			local base = card.base
			local flags = 0
			if card.facing == 'back' then flags = flags + 1 end
			if card.debuff then flags = flags + 2 end
			local ability = card.ability
			if ability then
				if ability.effect == 'Stone Card' then flags = flags + 4 end
				if ability.name == 'Wild Card' then flags = flags + 8 end
				if ability.forced_selection then flags = flags + 16 end
			end

			local v = (card.sort_id or card.ID or i) * 8192 + flags
			if base then
				v = v + (base.id or 0) * 256 + suit_key(base.suit) * 32
			end

			a = a + v
			local low = v % 100003
			b = b + low * low
		end

		-- Jokers change how a hand evaluates: Four Fingers, Shortcut, Smeared,
		-- Pareidolia and so on.
		local jokers = G.jokers and G.jokers.cards
		if jokers then
			a = a + #jokers * 7919
			for i = 1, #jokers do
				local joker = jokers[i]
				a = a + (joker.sort_id or joker.ID or i) + (joker.debuff and 31 or 0)
			end
		end

		return a, b
	end

	-- Exposed for debugging and for the offline correctness harness.
	HandPreview.internal = {
		analyse = analyse_hand,
		build_lines = build_lines,
		fingerprint = hand_fingerprint,
		unique_hands = unique_hands,
		lines = lines
	}

	local REFRESH_DELAY = 0.1
	local dirty, settle = true, 0
	local prev_a, prev_b
	local prev_preview_count, prev_include_facedown, prev_include_breakdown

	local function reset_preview_state()
		dirty, settle = true, 0
		prev_a, prev_b = nil, nil
		prev_preview_count, prev_include_facedown, prev_include_breakdown = nil, nil, nil
		displayed_count = -1
		trim(displayed_lines, 0)
	end
	HandPreview.reset = reset_preview_state

	local orig_game_start_run = Game.start_run
	function Game:start_run(args)
		orig_game_start_run(self, args)

		-- Containers stay registered in G.MOVEABLES and keep updating every
		-- frame for the rest of the session, so the old one has to go before a
		-- new run creates another.
		if HandPreview.container then
			HandPreview.container:remove()
			HandPreview.container = nil
		end
		reset_preview_state()

		local position = get_setting('position') or get_default_pos()

		debug_msg('start_run ', position.x, ' ', position.y)

		local container = HandPreviewContainer {
			T = {
				position.x,
				position.y,
				0,
				0
			},
			config = {
				align = 'tr',
				offset = { x = 0, y = 0 },
				major = self
			}
		}
		HandPreview.container = container
	end

	local orig_update = Game.update
	function Game:update(dt)
		orig_update(self, dt)

		flush_settings(dt)

		local container = HandPreview.container
		if not container then return end

		local preview_count = settings.preview_count or 0
		local state = self.STATE
		container.states.visible = (state == self.STATES.SELECTING_HAND or state == self.STATES.HAND_PLAYED or
			state == self.STATES.DRAW_TO_HAND) and preview_count > 0

		if not container.states.visible or not G.hand then return end

		local include_facedown = settings.include_facedown
		local include_breakdown = settings.include_breakdown
		if preview_count ~= prev_preview_count or include_facedown ~= prev_include_facedown or
			include_breakdown ~= prev_include_breakdown then
			prev_preview_count = preview_count
			prev_include_facedown = include_facedown
			prev_include_breakdown = include_breakdown
			dirty, settle = true, 0
		end

		local a, b = hand_fingerprint()
		if a ~= prev_a or b ~= prev_b then
			prev_a, prev_b = a, b
			dirty, settle = true, 0
		end

		if not dirty then return end

		-- Cards arrive one at a time during DRAW_TO_HAND, and the game only
		-- switches to SELECTING_HAND once the whole hand has been dealt. Wait
		-- for that instead of re-evaluating on every card.
		if state ~= self.STATES.SELECTING_HAND then return end

		-- ...and let anything else that is still shuffling the hand around
		-- (tarots, boss blinds, jokers destroying cards) finish first.
		settle = settle + dt
		if settle < REFRESH_DELAY then return end

		dirty = false

		-- This runs inside the game's update loop, and the hand evaluation it
		-- leans on can be replaced by other mods. If one of them throws, leave the
		-- last list on screen instead of taking the run down.
		local ok, err = pcall(analyse_hand, G.hand.cards)
		if ok then
			refresh_display()
		else
			debug_msg('analysis failed: ', err)
		end
	end

	----------------------------------------------
	--- Settings UI
	----------------------------------------------

	local function hand_preview_change_preview_count(args)
		set_setting('preview_count', args.to_val)
	end
	G.FUNCS.hand_preview_change_preview_count = hand_preview_change_preview_count

	local function hand_preview_change_anchor_point(args)
		set_setting('anchor', args.to_val)
	end
	G.FUNCS.hand_preview_change_anchor_point = hand_preview_change_anchor_point

	local function hand_preview_reset_position()
		set_setting('position', nil)
		set_setting('anchor', nil)

		if HandPreview.container then
			HandPreview.container.states.anchor = "Top Right"
			HandPreview.container:set_relative_pos(G.consumeables.T.x + G.consumeables.T.w,
				G.consumeables.T.y + G.consumeables.T.h + 0.4)

			if G.SETTINGS.paused then
				HandPreview.container:hard_set_T(HandPreview.container.T.x, HandPreview.container.T.y,
					HandPreview.container.T.w, HandPreview.container.T.h)
			end
			HandPreview.container:recalculate()
		end

		G:save_settings()
	end
	G.FUNCS.hand_preview_reset_position = hand_preview_reset_position

	G.FUNCS.open_hand_preview_settings = function(e, instant, back_func)
		G.SETTINGS.paused = true
		G.FUNCS.overlay_menu {
			definition = create_UIBox_generic_options({ back_func = back_func and back_func or 'settings', contents = {
				{
					n = G.UIT.R,
					config = {
						align = 'cm'
					},
					nodes = {
						{
							n = G.UIT.T,
							config = {
								text = "Hand Preview Settings",
								scale = 0.6,
								colour = G.C.UI.TEXT_LIGHT
							}
						}
					}
				},
				{
					n = G.UIT.R,
					config = {
						align = 'cm'
					},
					nodes = {
						create_option_cycle({
							id = "hand_preview_preview_count",
							label = "Preview Count",
							scale = 0.8,
							w = 1.2,
							options = { 0, 1, 2, 3, 4, 5 },
							opt_callback = 'hand_preview_change_preview_count',
							current_option = (
								G.SETTINGS.HandPreview.preview_count == 0 and 1 or
								G.SETTINGS.HandPreview.preview_count == 1 and 2 or
								G.SETTINGS.HandPreview.preview_count == 2 and 3 or
								G.SETTINGS.HandPreview.preview_count == 3 and 4 or
								G.SETTINGS.HandPreview.preview_count == 4 and 5 or
								G.SETTINGS.HandPreview.preview_count == 5 and 6 or
								4 -- Default to 3
							)
						})
					}
				},
				{
					n = G.UIT.R,
					config = {
						align = 'cm'
					},
					nodes = {
						create_toggle({
							id = "hand_preview_include_facedown_toggle",
							label = "Include Face-Down Cards",
							ref_table = G.SETTINGS.HandPreview,
							ref_value = "include_facedown"
						})
					}
				},
				{
					n = G.UIT.R,
					config = {
						align = 'cm'
					},
					nodes = {
						create_toggle({
							id = "hand_preview_include_breakdown_toggle",
							label = "Include Hand Breakdown",
							ref_table = G.SETTINGS.HandPreview,
							ref_value = "include_breakdown"
						})
					}
				},
				{
					n = G.UIT.R,
					config = {
						align = 'cm'
					},
					nodes = {
						UIBox_button { label = { "Reset window position" }, button = "hand_preview_reset_position", minw = 1.7, minh = 0.4, scale = 0.35 }
					}
				},
			} }),
			config = { offset = { x = 0, y = instant and 0 or 10 } }
		}
	end

	local setting_tabRef = G.UIDEF.settings_tab
	function G.UIDEF.settings_tab(tab)
		local setting_tab = setting_tabRef(tab)

		if tab == 'Game' then
			local button = {
				n = G.UIT.R,
				config = {
					align = 'cm'
				},
				nodes = {
					{
						n = G.UIT.C,
						config = {
							colour = G.C.RED,
							padding = 0.1,
							r = 0.1,
							hover = true,
							shadow = true,
							button = 'open_hand_preview_settings',
						},
						nodes = {
							{
								n = G.UIT.R,
								nodes = {
									{
										n = G.UIT.C,
										config = {
											minw = 0.2
										},
										nodes = {}
									},
									{
										n = G.UIT.C,
										nodes = {
											{
												n = G.UIT.R,
												nodes = {
													{
														n = G.UIT.T,
														config = {
															text = 'Hand Preview Settings',
															scale = 0.3,
															colour = G.C.UI.TEXT_LIGHT
														}
													}
												}
											},
											{
												n = G.UIT.R,
												config = {
													minh = 0.05
												},
												nodes = {}
											},
											{
												n = G.UIT.R,
												nodes = {
													{
														n = G.UIT.C,
														nodes = {
															{
																n = G.UIT.R,
																nodes = {
																	{
																		n = G.UIT.T,
																		config = {
																			text = 'Preview Count: ' ..
																				tostring(get_setting('preview_count')),
																			scale = 0.15,
																			colour = G.C.UI.TEXT_LIGHT
																		}
																	}
																}
															},
															{
																n = G.UIT.R,
																nodes = {
																	{
																		n = G.UIT.T,
																		config = {
																			text = 'Include Face-Down: ' ..
																				(get_setting('include_facedown') and 'Yes' or 'No'),
																			scale = 0.15,
																			colour = G.C.UI.TEXT_LIGHT
																		}
																	}
																}
															},
														}
													},
													{
														n = G.UIT.C,
														config = {
															minw = 0.2
														},
														nodes = {}
													},
													{
														n = G.UIT.C,
														nodes = {
															{
																n = G.UIT.R,
																nodes = {
																	{
																		n = G.UIT.T,
																		config = {
																			text = 'Include Breakdown: ' ..
																				(get_setting('include_breakdown') and 'Yes' or 'No'),
																			scale = 0.15,
																			colour = G.C.UI.TEXT_LIGHT
																		}
																	}
																}
															},
														}
													},
												}
											},
										}
									},
									{
										n = G.UIT.C,
										config = {
											minw = 0.2
										},
										nodes = {}
									},
								}
							}
						}
					}
				}
			}

			table.insert(setting_tab.nodes, button)
		end

		return setting_tab
	end
end

----------------------------------------------
------------MOD CODE END----------------------
