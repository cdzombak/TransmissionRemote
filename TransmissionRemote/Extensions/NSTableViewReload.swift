import AppKit
import DifferenceKit

public extension NSTableView {
    /// Applies multiple animated updates in stages using `StagedChangeset`.
    ///
    /// - Note: There are combination of changes that crash when applied simultaneously in `performBatchUpdates`.
    ///         Assumes that `StagedChangeset` has a minimum staged changesets to avoid it.
    ///         The data of the data-source needs to be updated synchronously before `performBatchUpdates` in every stages.
    ///
    /// - Parameters:
    ///   - stagedChangeset: A staged set of changes.
    ///   - animation: An option to animate the updates.
    ///   - interrupt: A closure that takes an changeset as its argument and returns `true` if the animated
    ///                updates should be stopped and performed reloadData. Default is nil.
    ///   - setData: A closure that takes the collection as a parameter.
    ///              The collection should be set to data-source of NSTableView.
    func reloadTable<C>(
        using stagedChangeset: StagedChangeset<C>,
        with animation: @autoclosure () -> NSTableView.AnimationOptions,
        interrupt: ((Changeset<C>) -> Bool)? = nil,
        setData: (C) -> Void
        ) {
        reloadTable(
            using: stagedChangeset,
            deleteRowsAnimation: animation(),
            insertRowsAnimation: animation(),
            reloadRowsAnimation: animation(),
            interrupt: interrupt,
            setData: setData
        )
    }

    /// Applies multiple animated updates in stages using `StagedChangeset`.
    ///
    /// - Note: There are combination of changes that crash when applied simultaneously in `performBatchUpdates`.
    ///         Assumes that `StagedChangeset` has a minimum staged changesets to avoid it.
    ///         The data of the data-source needs to be updated synchronously before `performBatchUpdates` in every stages.
    ///
    /// - Parameters:
    ///   - stagedChangeset: A staged set of changes.
    ///   - deleteRowsAnimation: An option to animate the row deletion.
    ///   - insertRowsAnimation: An option to animate the row insertion.
    ///   - reloadRowsAnimation: An option to animate the row reload.
    ///   - interrupt: A closure that takes an changeset as its argument and returns `true` if the animated
    ///                updates should be stopped and performed reloadData. Default is nil.
    ///   - setData: A closure that takes the collection as a parameter.
    ///              The collection should be set to data-source of NSTableView.
    func reloadTable<C>(
        using stagedChangeset: StagedChangeset<C>,
        deleteRowsAnimation: @autoclosure () -> NSTableView.AnimationOptions,
        insertRowsAnimation: @autoclosure () -> NSTableView.AnimationOptions,
        reloadRowsAnimation: @autoclosure () -> NSTableView.AnimationOptions,
        interrupt: ((Changeset<C>) -> Bool)? = nil,
        setData: (C) -> Void
        ) {
        if case .none = window, let data = stagedChangeset.last?.data {
            setData(data)
            return reloadData()
        }

        for changeset in stagedChangeset {
            if let interrupt = interrupt, interrupt(changeset), let data = stagedChangeset.last?.data {
                setData(data)
                return reloadData()
            }

            beginUpdates()
            setData(changeset.data)

            if !changeset.elementDeleted.isEmpty {
                removeRows(at: IndexSet(changeset.elementDeleted.map { $0.element }), withAnimation: deleteRowsAnimation())
            }

            if !changeset.elementInserted.isEmpty {
                insertRows(at: IndexSet(changeset.elementInserted.map { $0.element }), withAnimation: insertRowsAnimation())
            }

            if !changeset.elementUpdated.isEmpty {
                reloadData(forRowIndexes: IndexSet(changeset.elementUpdated.map { $0.element }), columnIndexes: IndexSet(0..<self.tableColumns.count))
            }

            if !changeset.elementMoved.isEmpty {
                var movesSorted = changeset.elementMoved.sorted { $0.target.element < $1.target.element  }
                for (index, _) in movesSorted.enumerated() {
                    if movesSorted[index].source.element >= movesSorted[index].target.element { // moving up
                        for i in index + 1 ..< movesSorted.count {
                            if movesSorted[index].target.element ... movesSorted[index].source.element ~= movesSorted[i].source.element {
                                movesSorted[i].source = ElementPath(element: movesSorted[i].source.element + 1, section: movesSorted[i].source.section)
                            }
                        }
                    } else { // moving down
                        // It's unclear, is such moves even possible in DifferenceKit or not
                        fatalError("Moving down is not implemented")
                    }
                }
                
                for (source, target) in /*changeset.elementMoved*/ movesSorted {
                    moveRow(at: source.element, to: target.element)
                }
            }

            endUpdates()
        }
    }
}
